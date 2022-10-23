use anyhow::Context;

use crate::{models as dbm, PgStore, StoreError};

impl PgStore {
    pub async fn get_view_tag(&self, id: i32) -> Result<Option<dbm::ViewTag>, StoreError> {
        let tag = sqlx::query_as!(dbm::ViewTag, r#"SELECT * FROM view_tag WHERE id = $1;"#, id)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting view tag from database")?;

        Ok(tag)
    }

    pub async fn get_view_tags(&self) -> Result<Vec<dbm::ViewTag>, StoreError> {
        let tags = sqlx::query_as!(dbm::ViewTag, r#"SELECT * FROM view_tag ORDER BY id ASC;"#)
            .fetch_all(&self.pool)
            .await
            .context("Error getting view tags from database")?;

        Ok(tags)
    }

    pub async fn update_tag(&self, id: i32, tag: &dbm::UpdateTag, user_id: i32) -> Result<bool, StoreError> {
        let success = sqlx::query_scalar_unchecked!(r#"SELECT update_tag($1, $2, $3);"#, id, tag, user_id)
            .fetch_one(&self.pool)
            .await
            .context("Error updating tag in database")?;

        Ok(success.unwrap())
    }
}
