use anyhow::Context;

use crate::{models as dbm, PgStore, StoreError};

impl PgStore {
    pub async fn create_user(&self, user: &dbm::NewUser) -> Result<dbm::User, StoreError> {
        let post = sqlx::query_as_unchecked!(dbm::User, r#"SELECT * FROM create_user($1);"#, user)
            .fetch_one(&self.pool)
            .await
            .context("Error creating user in database")?;

        Ok(post)
    }

    pub async fn get_user(&self, id: i32) -> Result<Option<dbm::User>, StoreError> {
        let user = sqlx::query_as!(dbm::User, r#"SELECT * FROM "user" WHERE id = $1;"#, id)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting user from database")?;

        Ok(user)
    }

    pub async fn get_user_by_name(&self, user_name: &str) -> Result<Option<dbm::User>, StoreError> {
        let user = sqlx::query_as!(dbm::User, r#"SELECT * FROM "user" WHERE name = $1;"#, user_name)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting user from database by name")?;

        Ok(user)
    }
}
