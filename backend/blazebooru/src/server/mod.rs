mod api;

use std::{net::SocketAddr, sync::Arc};

use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::Router;
use axum_client_ip::SecureClientIpSource;
use futures::Future;
use thiserror::Error;
use tokio::net::TcpListener;
use tower_http::services::ServeDir;
use tracing::{error, info};

use blazebooru_core::{config::BlazeBooruConfig, BlazeBooruCore};

use crate::auth::{AuthError, BlazeBooruAuth};

pub struct BlazeBooruServer {
    pub config: BlazeBooruConfig,
    pub auth: BlazeBooruAuth,
    pub core: BlazeBooruCore,
    pub serve_files: bool,
}

#[derive(Debug, Error)]
enum ApiError {
    #[error(transparent)]
    Anyhow(#[from] anyhow::Error),
    #[error(transparent)]
    AuthError(#[from] AuthError),
    #[error("Bad request")]
    BadRequest,
    #[error("Not found")]
    NotFound,
    #[error("Unauthorized")]
    Unauthorized,
}

impl BlazeBooruServer {
    pub async fn run_server(self, shutdown: impl Future<Output = ()> + Send + 'static) -> Result<(), anyhow::Error> {
        let api = api::router(&self.config);

        let server = Arc::new(self);

        let mut app = Router::new().nest("/api", api);

        // If file serving is enabled, serve public files under /f.
        // This should generally only be used for development.
        // On a production deployment, the public file path should
        // be served directly through a dedicated HTTP server instead.
        if server.serve_files {
            app = app.nest_service("/f", ServeDir::new(&server.core.public_path))
        }

        let app = app
            .layer(tower_http::trace::TraceLayer::new_for_http())
            .layer(SecureClientIpSource::RightmostXForwardedFor.into_extension())
            .with_state(server);

        let addr: SocketAddr = "[::]:3000".parse().unwrap();

        info!("Web server listening on: {addr}");
        let listener = TcpListener::bind(&addr).await?;
        axum::serve(listener, app).with_graceful_shutdown(shutdown).await?;

        Ok(())
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::Anyhow(err) => {
                error!("{err:#}");
                (StatusCode::INTERNAL_SERVER_ERROR, format!("{err:#}")).into_response()
            }
            Self::AuthError(AuthError::ExpiredToken) => (StatusCode::UNAUTHORIZED, ()).into_response(),
            Self::AuthError(err) => (StatusCode::BAD_REQUEST, format!("{err:#}")).into_response(),
            Self::BadRequest => (StatusCode::BAD_REQUEST, ()).into_response(),
            Self::NotFound => (StatusCode::NOT_FOUND, ()).into_response(),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, ()).into_response(),
        }
    }
}
