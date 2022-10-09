use std::sync::Arc;

use anyhow::{anyhow, Context};
use axum::extract::ContentLengthLimit;
use axum::extract::Multipart;
use axum::extract::Path;
use axum::extract::Query;
use axum::extract::State;
use axum::routing::get;
use axum::routing::post;
use axum::Json;
use axum::Router;
use serde::Deserialize;

use blazebooru_models::local as lm;
use blazebooru_models::local::HashedFile;
use blazebooru_models::view as vm;

use crate::server::api::Authorized;
use crate::server::ApiError;
use crate::server::BlazeBooruServer;

const MAX_IMAGE_SIZE: u64 = 10_000_000; // 10MB

#[derive(Debug, Deserialize)]
struct PostInfo {
    title: Option<String>,
    description: Option<String>,

    #[serde(default)]
    tags: Vec<String>,
}

#[derive(Deserialize)]
struct PaginatedQuery {
    #[serde(default)]
    offset: i32,
    limit: i32,
}

#[derive(Deserialize)]
struct PostSearchQuery {
    #[serde(rename = "t")]
    #[serde(default)]
    #[serde(deserialize_with = "crate::deserialize::comma_separated")]
    include_tags: Vec<String>,
    #[serde(rename = "e")]
    #[serde(default)]
    #[serde(deserialize_with = "crate::deserialize::comma_separated")]
    exclude_tags: Vec<String>,
}

pub fn router(server: Arc<BlazeBooruServer>) -> Router<Arc<BlazeBooruServer>> {
    Router::with_state(server)
        .route("/:id", get(get_view_post))
        .route("/count", get(search_view_posts_count))
        .route("/search", get(search_view_posts))
        .route("/upload", post(upload_post))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_post(
    State(server): State<Arc<BlazeBooruServer>>,
    Path(id): Path<i32>,
) -> Result<Json<vm::Post>, ApiError> {
    let post = server
        .core
        .get_view_post(id)
        .await
        .context("Error getting thread")?;

    Ok(Json(post.ok_or(ApiError::NotFound)?))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn search_view_posts(
    State(server): State<Arc<BlazeBooruServer>>,
    Query(PostSearchQuery {
        include_tags,
        exclude_tags,
    }): Query<PostSearchQuery>,
    Query(PaginatedQuery { offset, limit }): Query<PaginatedQuery>,
) -> Result<Json<Vec<vm::Post>>, ApiError> {
    let include_tags = include_tags.iter().map(|t| t.as_str()).collect();
    let exclude_tags = exclude_tags.iter().map(|t| t.as_str()).collect();

    let posts = server
        .core
        .search_view_posts(include_tags, exclude_tags, offset, limit)
        .await
        .context("Error getting thread")?;

    Ok(Json(posts))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn search_view_posts_count(
    State(server): State<Arc<BlazeBooruServer>>,
    Query(PostSearchQuery {
        include_tags,
        exclude_tags,
    }): Query<PostSearchQuery>,
) -> Result<Json<i32>, ApiError> {
    let include_tags = include_tags.iter().map(|t| t.as_str()).collect();
    let exclude_tags = exclude_tags.iter().map(|t| t.as_str()).collect();

    let stats = server
        .core
        .search_view_posts_count(include_tags, exclude_tags)
        .await
        .context("Error getting posts pagination stats")?;

    Ok(Json(stats))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn upload_post(
    State(server): State<Arc<BlazeBooruServer>>,
    auth: Authorized,
    ContentLengthLimit(mut multipart): ContentLengthLimit<Multipart, { MAX_IMAGE_SIZE }>,
) -> Result<Json<i32>, ApiError> {
    let mut info: Option<PostInfo> = None;
    let mut file: Option<(HashedFile, String)> = None;

    while let Some(mut field) = multipart
        .next_field()
        .await
        .context("Error getting next multipart field")?
    {
        let field_name = field.name().ok_or_else(|| anyhow!("Field has no name."))?;

        match field_name {
            "info" => {
                let json = field
                    .text()
                    .await
                    .map_err(|err| ApiError::Anyhow(err.into()))?;

                info = Some(serde_json::from_str(&json).context("Deserializing post info")?);
            }
            "file" => {
                let filename = field
                    .file_name()
                    .ok_or_else(|| anyhow!("Image has no filename."))?
                    .to_string();

                let hashed_file = server.core.hash_stream_to_temp_file(&mut field).await?;

                file = Some((hashed_file, filename));
            }
            _ => {}
        }
    }

    if let (Some(info), Some((file, filename))) = (info, file) {
        let new_post = lm::NewPost {
            user_id: auth.claims.user_id,
            title: info.title.map(|s| s.into()),
            description: info.description.map(|s| s.into()),
            filename: filename.into(),
            file,
            tags: info.tags.iter().map(|t| t.as_str()).collect(),
        };

        let new_post_id = server
            .core
            .create_post(new_post)
            .await
            .context("Error creating post")?;

        Ok(Json(new_post_id))
    } else {
        Err(ApiError::BadRequest)
    }
}
