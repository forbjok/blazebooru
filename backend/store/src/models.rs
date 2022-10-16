use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
pub struct User {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub name: String,
    pub password_hash: String,
}

#[derive(Debug, sqlx::FromRow)]
pub struct Post {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub user_id: i32,
    pub title: Option<String>,
    pub description: Option<String>,
    pub source: Option<String>,
    pub filename: String,
    pub size: i32,
    pub width: i32,
    pub height: i32,
    pub hash: String,
    pub ext: String,
    pub tn_ext: String,
    pub tags: Vec<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct ViewPost {
    pub id: Option<i32>,
    pub created_at: Option<DateTime<Utc>>,
    pub user_id: Option<i32>,
    pub user_name: Option<String>,
    pub title: Option<String>,
    pub description: Option<String>,
    pub source: Option<String>,
    pub filename: Option<String>,
    pub size: Option<i32>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub hash: Option<String>,
    pub ext: Option<String>,
    pub tn_ext: Option<String>,
    pub tags: Option<Vec<String>>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct PostComment {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub user_id: Option<i32>,
    pub user_name: Option<String>,
    pub post_id: i32,
    pub comment: String,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "new_post")]
pub struct NewPost {
    pub user_id: Option<i32>,
    pub title: Option<String>,
    pub description: Option<String>,
    pub source: Option<String>,
    pub filename: Option<String>,
    pub size: Option<i32>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub hash: Option<String>,
    pub ext: Option<String>,
    pub tn_ext: Option<String>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "update_post")]
pub struct UpdatePost {
    pub id: Option<i32>,

    pub title: Option<String>,
    pub description: Option<String>,
    pub source: Option<String>,

    pub add_tags: Vec<String>,
    pub remove_tags: Vec<String>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "new_user")]
pub struct NewUser {
    pub name: Option<String>,
    pub password_hash: Option<String>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "new_post_comment")]
pub struct NewPostComment {
    pub post_id: i32,
    pub comment: String,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "page_info")]
pub struct PageInfo {
    pub no: Option<i32>,
    pub start_id: Option<i32>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "refresh_refresh_token_result")]
pub struct CreateRefreshTokenResult {
    pub token: Option<Uuid>,
    pub session: Option<i64>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "refresh_refresh_token_result")]
pub struct RefreshRefreshTokenResult {
    pub token: Option<Uuid>,
    pub session: Option<i64>,
    pub user_id: Option<i32>,
}
