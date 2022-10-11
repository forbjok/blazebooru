use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "user")]
pub struct User {
    pub id: Option<i32>,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
    pub name: Option<String>,
    pub password_hash: Option<String>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "post")]
pub struct Post {
    pub id: Option<i32>,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
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
    pub tags: Vec<String>,
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
#[sqlx(type_name = "new_user")]
pub struct NewUser {
    pub name: Option<String>,
    pub password_hash: Option<String>,
}

#[derive(Debug, sqlx::Type)]
#[sqlx(type_name = "view_post")]
pub struct ViewPost {
    pub id: Option<i32>,
    pub created_at: Option<DateTime<Utc>>,
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
    pub tags: Vec<String>,
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
