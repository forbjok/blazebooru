use std::path::PathBuf;
use std::{env, fs};

use anyhow::Context;

use blazebooru_store::PgStore;
use config::BlazeBooruConfig;

mod auth;
mod comment;
pub mod config;
pub mod image;
mod post;
mod tag;
mod user;

pub struct BlazeBooruCore {
    pub temp_path: PathBuf,
    pub public_path: PathBuf,
    pub public_original_path: PathBuf,
    pub public_thumbnail_path: PathBuf,
    store: PgStore,
}

impl BlazeBooruCore {
    pub fn new(config: &BlazeBooruConfig) -> Result<Self, anyhow::Error> {
        let files_path = env::var("BLAZEBOORU_FILES_PATH")
            .ok()
            .map(PathBuf::from)
            .or_else(|| config.files_path.clone())
            .expect("BLAZEBOORU_FILES_PATH not set");

        let temp_path = files_path.join("temp");

        let public_path = files_path.join("public");
        let public_original_path = public_path.join("o");
        let public_thumbnail_path = public_path.join("t");

        // Ensure that all necessary directories exist
        fs::create_dir_all(&temp_path)?;
        fs::create_dir_all(&public_original_path)?;
        fs::create_dir_all(&public_thumbnail_path)?;

        let database_uri = env::var("DATABASE_URL")
            .ok()
            .or_else(|| config.database_uri.clone())
            .context("DATABASE_URL not set")?;

        let store = PgStore::new(&database_uri)?;

        Ok(Self {
            temp_path,
            public_path,
            public_original_path,
            public_thumbnail_path,
            store,
        })
    }

    pub async fn migrate(&self) -> Result<(), anyhow::Error> {
        self.store.migrate().await
    }
}
