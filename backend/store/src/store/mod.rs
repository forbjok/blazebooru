mod auth;
mod comment;
mod post;
mod user;

use anyhow::Context;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StoreError {
    #[error(transparent)]
    Anyhow(#[from] anyhow::Error),
}

pub struct PgStore {
    pool: sqlx::postgres::PgPool,
}

impl PgStore {
    pub fn new(uri: &str) -> Result<Self, StoreError> {
        let pool = sqlx::PgPool::connect_lazy(uri).context("Error creating PgPool")?;

        Ok(Self { pool })
    }
}

impl PgStore {
    pub async fn migrate(&self) -> Result<(), anyhow::Error> {
        sqlx::migrate!().run(&self.pool).await?;

        Ok(())
    }
}
