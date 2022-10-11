use anyhow::Context;

use crate::{models as dbm, PgStore, StoreError};

impl PgStore {
    pub async fn get_post(&self, id: i32) -> Result<Option<dbm::Post>, StoreError> {
        let post = sqlx::query_as!(dbm::Post, r#"SELECT * FROM post WHERE id = $1;"#, id)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting post from database")?;

        Ok(post)
    }

    pub async fn create_post(&self, post: &dbm::NewPost, tags: &[&str]) -> Result<i32, StoreError> {
        let new_post_id = sqlx::query_scalar_unchecked!(r#"SELECT create_post($1, $2);"#, post, tags)
            .fetch_one(&self.pool)
            .await
            .context("Error creating post in database")?;

        Ok(new_post_id.unwrap())
    }

    pub async fn update_post(&self, post: &dbm::UpdatePost, user_id: i32) -> Result<bool, StoreError> {
        let success = sqlx::query_scalar_unchecked!(r#"SELECT update_post($1, $2);"#, post, user_id)
            .fetch_one(&self.pool)
            .await
            .context("Error updating post in database")?;

        Ok(success.unwrap())
    }

    pub async fn get_view_post(&self, id: i32) -> Result<Option<dbm::ViewPost>, StoreError> {
        let post = sqlx::query_as!(dbm::ViewPost, r#"SELECT * FROM view_post WHERE id = $1;"#, id)
            .fetch_optional(&self.pool)
            .await
            .context("Error getting view post from database")?;

        Ok(post)
    }

    pub async fn get_view_posts(
        &self,
        include_tags: &[String],
        exclude_tags: &[String],
        start_id: i32,
        limit: i32,
    ) -> Result<Vec<dbm::ViewPost>, StoreError> {
        let posts = sqlx::query_as!(
            dbm::ViewPost,
            r#"SELECT * FROM get_view_posts($1, $2, $3, $4);"#,
            include_tags,
            exclude_tags,
            start_id,
            limit
        )
        .fetch_all(&self.pool)
        .await
        .context("Error getting view posts from database")?;

        Ok(posts)
    }

    pub async fn calculate_pages(
        &self,
        include_tags: &[&str],
        exclude_tags: &[&str],
        posts_per_page: i32,
        page_count: i32,
        origin_page: Option<dbm::PageInfo>,
    ) -> Result<Vec<dbm::PageInfo>, StoreError> {
        let pages = if page_count < 0 {
            sqlx::query_as_unchecked!(
                dbm::PageInfo,
                r#"SELECT * FROM unnest(calculate_pages_reverse($1, $2, $3, $4, $5));"#,
                include_tags,
                exclude_tags,
                posts_per_page,
                -page_count,
                origin_page
            )
            .fetch_all(&self.pool)
            .await
            .context("Error calculating last page")?
        } else {
            sqlx::query_as_unchecked!(
                dbm::PageInfo,
                r#"SELECT * FROM unnest(calculate_pages($1, $2, $3, $4, $5));"#,
                include_tags,
                exclude_tags,
                posts_per_page,
                page_count,
                origin_page
            )
            .fetch_all(&self.pool)
            .await
            .context("Error calculating last page")?
        };

        Ok(pages)
    }

    pub async fn calculate_last_page(
        &self,
        include_tags: &[&str],
        exclude_tags: &[&str],
        posts_per_page: i32,
    ) -> Result<dbm::PageInfo, StoreError> {
        let page = sqlx::query_as_unchecked!(
            dbm::PageInfo,
            r#"SELECT * FROM calculate_last_page($1, $2, $3);"#,
            include_tags,
            exclude_tags,
            posts_per_page
        )
        .fetch_one(&self.pool)
        .await
        .context("Error calculating last page")?;

        Ok(page)
    }
}
