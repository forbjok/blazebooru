use anyhow::Context;
use uuid::Uuid;

use crate::{
    models::{CreateRefreshTokenResult, RefreshRefreshTokenResult},
    PgStore,
};

impl PgStore {
    pub async fn create_refresh_token(
        &self,
        claims: &str,
    ) -> Result<CreateRefreshTokenResult, anyhow::Error> {
        let token = sqlx::query_as_unchecked!(
            CreateRefreshTokenResult,
            r#"SELECT * FROM create_refresh_token($1);"#,
            claims
        )
        .fetch_one(&self.pool)
        .await
        .context("Error creating refresh token")?;

        Ok(token)
    }

    pub async fn invalidate_session(&self, session: i64) -> Result<(), anyhow::Error> {
        sqlx::query_as_unchecked!(
            CreateRefreshTokenResult,
            r#"SELECT * FROM invalidate_session($1);"#,
            session
        )
        .execute(&self.pool)
        .await
        .context("Error invalidating session")?;

        Ok(())
    }

    pub async fn refresh_refresh_token(
        &self,
        token: Uuid,
    ) -> Result<RefreshRefreshTokenResult, anyhow::Error> {
        let result = sqlx::query_as_unchecked!(
            RefreshRefreshTokenResult,
            r#"SELECT * FROM refresh_refresh_token($1);"#,
            token
        )
        .fetch_optional(&self.pool)
        .await?
        .context("Error refreshing refresh token")?;

        Ok(result)
    }
}
