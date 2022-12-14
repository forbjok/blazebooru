use std::{borrow::Cow, path::PathBuf};

use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::view as vm;

pub type Post = vm::Post;

#[derive(Debug)]
pub struct HashedFile {
    pub hash: String,
    pub size: u64,
    pub path: PathBuf,
}

#[derive(Debug)]
pub struct User {
    pub id: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub name: String,
}

#[derive(Debug)]
pub struct NewPost<'a> {
    pub user_id: i32,
    pub title: Option<Cow<'a, str>>,
    pub description: Option<Cow<'a, str>>,
    pub source: Option<Cow<'a, str>>,
    pub filename: Cow<'a, str>,
    pub file: HashedFile,
    pub tags: Vec<&'a str>,
}

#[derive(Debug)]
pub struct NewUser<'a> {
    pub name: Cow<'a, str>,
    pub password: Cow<'a, str>,
}

#[derive(Debug)]
pub struct CreateRefreshTokenResult {
    pub token: Uuid,
    pub session: i64,
}

#[derive(Debug)]
pub struct RefreshRefreshTokenResult {
    pub token: Uuid,
    pub session: i64,
    pub user_id: i32,
}
