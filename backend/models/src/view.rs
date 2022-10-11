use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct Post {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub user_id: i32,
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

#[derive(Debug, Deserialize)]
pub struct UpdatePost {
    pub title: Option<String>,
    pub description: Option<String>,
    pub source: Option<String>,

    pub add_tags: Vec<String>,
    pub remove_tags: Vec<String>,
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
