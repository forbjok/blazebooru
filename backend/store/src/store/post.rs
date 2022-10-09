use anyhow::Context;

use crate::{models as dbm, PgStore, StoreError};

impl PgStore {
    pub async fn get_post(&self, id: i32) -> Result<Option<dbm::Post>, StoreError> {
        let post = sqlx::query_as_unchecked!(dbm::Post, r#"SELECT * FROM post WHERE id = $1;"#, id)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting post from database")?;

        Ok(post)
    }

    pub async fn create_post(&self, post: &dbm::NewPost, tags: &[&str]) -> Result<i32, StoreError> {
        let new_post_id =
            sqlx::query_scalar_unchecked!(r#"SELECT create_post($1, $2);"#, post, tags)
                .fetch_one(&self.pool)
                .await
                .context("Error creating post in database")?;

        Ok(new_post_id.unwrap())
    }

    pub async fn get_view_post(&self, id: i32) -> Result<Option<dbm::ViewPost>, StoreError> {
        let post = sqlx::query_as_unchecked!(
            dbm::ViewPost,
            r#"SELECT * FROM view_post WHERE id = $1;"#,
            id
        )
        .fetch_optional(&self.pool)
        .await
        .context("Error getting view post from database")?;

        Ok(post)
    }

    pub async fn search_view_posts(
        &self,
        include_tags: &[&str],
        exclude_tags: &[&str],
        offset: i32,
        limit: i32,
    ) -> Result<Vec<dbm::ViewPost>, StoreError> {
        let posts = sqlx::query_as_unchecked!(
            dbm::ViewPost,
            r#"SELECT * FROM search_view_posts($1, $2, $3, $4);"#,
            include_tags,
            exclude_tags,
            offset,
            limit
        )
        .fetch_all(&self.pool)
        .await
        .context("Error getting view posts from database")?;

        Ok(posts)
    }

    pub async fn search_view_posts_count(
        &self,
        include_tags: &[&str],
        exclude_tags: &[&str],
    ) -> Result<i32, StoreError> {
        let stats = sqlx::query_scalar_unchecked!(
            r#"SELECT search_view_posts_count($1, $2);"#,
            include_tags,
            exclude_tags
        )
        .fetch_one(&self.pool)
        .await
        .context("Error getting post pagination stats from database")?;

        Ok(stats.unwrap())
    }
}
