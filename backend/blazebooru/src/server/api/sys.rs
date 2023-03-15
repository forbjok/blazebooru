use std::sync::Arc;

use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};

use blazebooru_models::view as vm;

use crate::server::{ApiError, BlazeBooruServer};

use super::DEFAULT_MAX_IMAGE_SIZE;

pub fn router() -> Router<Arc<BlazeBooruServer>> {
    Router::new().route("/config", get(get_config))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_config(State(server): State<Arc<BlazeBooruServer>>) -> Result<Json<vm::Config>, ApiError> {
    let config = vm::Config {
        max_image_size: server.config.max_image_size.unwrap_or(DEFAULT_MAX_IMAGE_SIZE),
    };

    Ok(Json(config))
}
