use std::net::SocketAddr;
use std::sync::Arc;

use axum::extract::{ConnectInfo, State};
use axum::routing::post;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use blazebooru_models::local as lm;

use crate::auth::{AuthClaims, JwtClaims, SessionClaims};
use crate::server::api::Authorized;
use crate::server::{ApiError, BlazeBooruServer};

#[derive(Debug, Deserialize)]
struct LoginRequest {
    name: String,
    password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub exp: usize,
    pub refresh_token: Uuid,
}

#[derive(Debug, Deserialize)]
struct RefreshRequest {
    pub refresh_token: Uuid,
}

pub fn router(server: Arc<BlazeBooruServer>) -> Router<Arc<BlazeBooruServer>> {
    Router::with_state(server)
        .route("/login", post(login))
        .route("/logout", post(logout))
        .route("/refresh", post(refresh))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn login(
    State(server): State<Arc<BlazeBooruServer>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, ApiError> {
    let user = server.core.login(&req.name, &req.password).await?;

    if let Some(user) = user {
        let lm::CreateRefreshTokenResult {
            token: refresh_token,
            session,
        } = server.core.create_refresh_token(user.id, addr.ip()).await?;

        let claims = AuthClaims { user_id: user.id };
        let claims = SessionClaims { session, claims };

        let claims = JwtClaims::short(claims);
        let exp = claims.exp;
        let access_token = server.auth.generate_token(&claims)?;

        Ok(Json(LoginResponse {
            access_token,
            exp,
            refresh_token,
        }))
    } else {
        Err(ApiError::Unauthorized)
    }
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn logout(
    State(server): State<Arc<BlazeBooruServer>>,
    auth: Authorized,
) -> Result<(), ApiError> {
    server.core.logout(auth.session).await?;

    Ok(())
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn refresh(
    State(server): State<Arc<BlazeBooruServer>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(req): Json<RefreshRequest>,
) -> Result<Json<LoginResponse>, ApiError> {
    if let Some(lm::RefreshRefreshTokenResult {
        token: refresh_token,
        session,
        user_id,
    }) = server
        .core
        .refresh_refresh_token(req.refresh_token, addr.ip())
        .await?
    {
        let claims = AuthClaims { user_id };
        let claims = SessionClaims { session, claims };

        let claims = JwtClaims::short(claims);
        let access_token = server.auth.generate_token(&claims)?;
        let exp = claims.exp;

        return Ok(Json(LoginResponse {
            access_token,
            exp,
            refresh_token,
        }));
    }

    Err(ApiError::Unauthorized)
}
