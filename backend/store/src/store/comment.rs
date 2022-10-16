use anyhow::Context;

use crate::{models as dbm, PgStore, StoreError};

impl PgStore {
    pub async fn create_post_comment(
        &self,
        comment: dbm::NewPostComment,
        user_id: Option<i32>,
    ) -> Result<dbm::PostComment, StoreError> {
        let comment = sqlx::query_as_unchecked!(
            dbm::PostComment,
            r#"SELECT * FROM create_post_comment($1, $2);"#,
            comment,
            user_id
        )
        .fetch_one(&self.pool)
        .await
        .context("Error creating post comment in database")?;

        Ok(comment)
    }

    pub async fn get_post_comments(&self, post_id: i32) -> Result<Vec<dbm::PostComment>, StoreError> {
        let comments = sqlx::query_as!(
            dbm::PostComment,
            r#"SELECT * FROM post_comment WHERE post_id = $1 ORDER BY id ASC;"#,
            Some(post_id)
        )
        .fetch_all(&self.pool)
        .await
        .context("Error getting post comments from database")?;

        Ok(comments)
    }
}
