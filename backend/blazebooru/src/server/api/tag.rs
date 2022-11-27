use std::sync::Arc;

use anyhow::Context;
use axum::extract::Path;
use axum::extract::State;
use axum::routing::{get, post};
use axum::Json;
use axum::Router;

use blazebooru_models::view as vm;

use crate::server::api::Authorized;
use crate::server::ApiError;
use crate::server::BlazeBooruServer;

pub fn router() -> Router<Arc<BlazeBooruServer>> {
    Router::new()
        .route("/", get(get_view_tags))
        .route("/:id", get(get_view_tag))
        .route("/:id/update", post(update_tag))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_tag(
    State(server): State<Arc<BlazeBooruServer>>,
    Path(id): Path<i32>,
) -> Result<Json<vm::Tag>, ApiError> {
    let tag = server.core.get_view_tag(id).await.context("Error getting view tag")?;

    Ok(Json(tag.ok_or(ApiError::NotFound)?))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_tags(State(server): State<Arc<BlazeBooruServer>>) -> Result<Json<Vec<vm::Tag>>, ApiError> {
    let tags = server.core.get_view_tags().await.context("Error getting view tags")?;

    Ok(Json(tags))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn update_tag(
    State(server): State<Arc<BlazeBooruServer>>,
    auth: Authorized,
    Path(id): Path<i32>,
    Json(req): Json<vm::UpdateTag>,
) -> Result<(), ApiError> {
    let success = server
        .core
        .update_tag(id, req, auth.claims.user_id)
        .await
        .context("Error updating tag")?;

    if !success {
        return Err(ApiError::NotFound);
    }

    Ok(())
}
