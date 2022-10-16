use std::sync::Arc;

use anyhow::{anyhow, Context};
use axum::extract::ContentLengthLimit;
use axum::extract::Multipart;
use axum::extract::Path;
use axum::extract::Query;
use axum::extract::State;
use axum::routing::{get, post};
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

#[derive(Deserialize)]
struct CalculatePagesQuery {
    #[serde(rename = "pc")]
    page_count: i32,
    #[serde(rename = "opno")]
    origin_page_no: Option<i32>,
    #[serde(rename = "opsid")]
    origin_page_start_id: Option<i32>,
}

#[derive(Deserialize)]
struct CalculatePageQuery {
    #[serde(rename = "ppp")]
    posts_per_page: i32,
}

#[derive(Debug, Deserialize)]
struct PostInfo {
    title: Option<String>,
    description: Option<String>,
    source: Option<String>,

    #[serde(default)]
    tags: Vec<String>,
}

#[derive(Deserialize)]
struct PaginatedQuery {
    #[serde(default)]
    #[serde(rename = "sid")]
    start_id: i32,
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
        .route("/", get(get_view_posts))
        .route("/:id", get(get_view_post))
        .route("/:id/update", post(update_post))
        .route("/:id/comments", get(get_post_comments))
        .route("/:id/comments/new", post(post_comment))
        .route("/by-hash/:hash", get(get_view_post_by_hash))
        .route("/pages", get(calculate_pages))
        .route("/pages/last", get(calculate_last_page))
        .route("/upload", post(upload_post))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_post(
    State(server): State<Arc<BlazeBooruServer>>,
    Path(id): Path<i32>,
) -> Result<Json<vm::Post>, ApiError> {
    let post = server.core.get_view_post(id).await.context("Error getting view post")?;

    Ok(Json(post.ok_or(ApiError::NotFound)?))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_post_by_hash(
    State(server): State<Arc<BlazeBooruServer>>,
    Path(hash): Path<String>,
) -> Result<Json<vm::Post>, ApiError> {
    let post = server
        .core
        .get_view_post_by_hash(&hash)
        .await
        .context("Error getting view post by hash")?;

    Ok(Json(post.ok_or(ApiError::NotFound)?))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn update_post(
    State(server): State<Arc<BlazeBooruServer>>,
    auth: Authorized,
    Path(id): Path<i32>,
    Json(req): Json<vm::UpdatePost>,
) -> Result<(), ApiError> {
    let post = server
        .core
        .update_post(id, req, auth.claims.user_id)
        .await
        .context("Error updating post")?;

    if !post {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_view_posts(
    State(server): State<Arc<BlazeBooruServer>>,
    Query(PostSearchQuery {
        include_tags,
        exclude_tags,
    }): Query<PostSearchQuery>,
    Query(PaginatedQuery { start_id, limit }): Query<PaginatedQuery>,
) -> Result<Json<Vec<vm::Post>>, ApiError> {
    let posts = server
        .core
        .get_view_posts(include_tags, exclude_tags, start_id, limit)
        .await
        .context("Error getting view posts")?;

    Ok(Json(posts))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn calculate_pages(
    State(server): State<Arc<BlazeBooruServer>>,
    Query(PostSearchQuery {
        include_tags,
        exclude_tags,
    }): Query<PostSearchQuery>,
    Query(CalculatePageQuery { posts_per_page }): Query<CalculatePageQuery>,
    Query(CalculatePagesQuery {
        page_count,
        origin_page_no,
        origin_page_start_id,
    }): Query<CalculatePagesQuery>,
) -> Result<Json<Vec<vm::PageInfo>>, ApiError> {
    let include_tags = include_tags.iter().map(|t| t.as_str()).collect();
    let exclude_tags = exclude_tags.iter().map(|t| t.as_str()).collect();

    let origin_page = if let (Some(no), Some(start_id)) = (origin_page_no, origin_page_start_id) {
        Some(vm::PageInfo { no, start_id })
    } else {
        None
    };

    let pages = server
        .core
        .calculate_pages(include_tags, exclude_tags, posts_per_page, page_count, origin_page)
        .await
        .context("Error calculating pages")?;

    Ok(Json(pages))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn calculate_last_page(
    State(server): State<Arc<BlazeBooruServer>>,
    Query(PostSearchQuery {
        include_tags,
        exclude_tags,
    }): Query<PostSearchQuery>,
    Query(CalculatePageQuery { posts_per_page }): Query<CalculatePageQuery>,
) -> Result<Json<vm::PageInfo>, ApiError> {
    let include_tags = include_tags.iter().map(|t| t.as_str()).collect();
    let exclude_tags = exclude_tags.iter().map(|t| t.as_str()).collect();

    let page = server
        .core
        .calculate_last_page(include_tags, exclude_tags, posts_per_page)
        .await
        .context("Error calculating last page")?;

    Ok(Json(page))
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
                let json = field.text().await.map_err(|err| ApiError::Anyhow(err.into()))?;

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
            source: info.source.map(|s| s.into()),
            filename: filename.into(),
            file,
            tags: info.tags.iter().map(|t| t.as_str()).collect(),
        };

        let new_post_id = server.core.create_post(new_post).await.context("Error creating post")?;

        Ok(Json(new_post_id))
    } else {
        Err(ApiError::BadRequest)
    }
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn get_post_comments(
    State(server): State<Arc<BlazeBooruServer>>,
    Path(id): Path<i32>,
) -> Result<Json<Vec<vm::Comment>>, ApiError> {
    let comments = server
        .core
        .get_post_comments(id)
        .await
        .context("Error getting post comments")?;

    Ok(Json(comments))
}

#[axum::debug_handler(state = Arc<BlazeBooruServer>)]
async fn post_comment(
    State(server): State<Arc<BlazeBooruServer>>,
    auth: Option<Authorized>,
    Path(id): Path<i32>,
    Json(req): Json<vm::NewPostComment>,
) -> Result<Json<vm::Comment>, ApiError> {
    let comment = server
        .core
        .create_post_comment(req, id, auth.map(|a| a.claims.user_id))
        .await
        .context("Error creating post comment")?;

    Ok(Json(comment))
}
