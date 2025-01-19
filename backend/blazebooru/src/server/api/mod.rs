mod auth;
mod post;
mod sys;
mod tag;
mod user;

use std::sync::Arc;

use axum::{
    extract::{FromRequestParts, OptionalFromRequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    RequestPartsExt, Router,
};

use axum_extra::{
    headers::{authorization::Bearer, Authorization},
    TypedHeader,
};
use blazebooru_core::config::BlazeBooruConfig;

use crate::{
    auth::{AuthClaims, AuthError, SessionClaims},
    server::BlazeBooruServer,
};

#[derive(Debug)]
struct Authorized {
    session: i64,
    claims: AuthClaims,
}

pub fn router(config: &BlazeBooruConfig) -> Router<Arc<BlazeBooruServer>> {
    let auth = auth::router();
    let post = post::router(config);
    let sys = sys::router();
    let user = user::router();
    let tag = tag::router();

    Router::new()
        .nest("/auth", auth)
        .nest("/sys", sys)
        .nest("/post", post)
        .nest("/user", user)
        .nest("/tag", tag)
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let status = match self {
            AuthError::ExpiredToken => StatusCode::UNAUTHORIZED,
            AuthError::TokenCreation => StatusCode::INTERNAL_SERVER_ERROR,
            AuthError::InvalidToken => StatusCode::BAD_REQUEST,
        };

        (status, self.to_string()).into_response()
    }
}

impl FromRequestParts<Arc<BlazeBooruServer>> for Authorized {
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, state: &Arc<BlazeBooruServer>) -> Result<Self, Self::Rejection> {
        let authorized = Option::<Authorized>::from_request_parts(parts, state).await;

        match authorized {
            Ok(v) => v.ok_or(AuthError::InvalidToken),
            Err(err) => Err(err),
        }
    }
}

impl OptionalFromRequestParts<Arc<BlazeBooruServer>> for Authorized {
    type Rejection = AuthError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &Arc<BlazeBooruServer>,
    ) -> Result<Option<Self>, Self::Rejection> {
        // Extract the token from the authorization header
        let auth_header = parts
            .extract::<Option<TypedHeader<Authorization<Bearer>>>>()
            .await
            .map_err(|_| AuthError::InvalidToken)?;

        let Some(TypedHeader(Authorization(bearer))) = auth_header else {
            return Ok(None);
        };

        let token = bearer.token();

        let SessionClaims { session, claims } = state.auth.verify::<SessionClaims>(token)?;

        Ok(Some(Authorized { session, claims }))
    }
}
