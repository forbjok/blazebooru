use chrono::{DateTime, Utc};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct Post {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub user_name: String,
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

#[derive(Debug, Serialize)]
pub struct User {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct PageInfo {
    pub no: i32,
    pub start_id: i32,
}
