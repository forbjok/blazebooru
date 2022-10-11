use anyhow::Context;

use blazebooru_models::local as lm;
use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;

use blazebooru_store::transform::dbm_update_post_from_vm;
use image::GenericImageView;

use crate::image::ProcessImageResult;

use super::BlazeBooruCore;

const THUMBNAIL_SIZE: u32 = 200;

impl BlazeBooruCore {
    pub async fn create_post(&self, post: lm::NewPost<'_>) -> Result<i32, anyhow::Error> {
        let size = post.file.size as i32;

        // Process image
        let ProcessImageResult {
            hash,
            ext,
            original_image_path,
        } = self
            .process_image(post.file, &post.filename, &self.public_original_path)
            .await?;

        // Open image file
        let img = image::open(&original_image_path)?;
        let (width, height) = img.dimensions();

        // Generate thumbnail
        let tn_ext = "jpg";
        let thumbnail_filename = format!("{hash}.{tn_ext}");
        let thumbnail_path = self.public_thumbnail_path.join(thumbnail_filename);

        // If thumbnail does not already exist, create it.
        let thumbnail_exists = thumbnail_path.exists();
        if !thumbnail_exists {
            // Only resize image if it exceeds the thumbnail dimensions
            let tn_img = if width > THUMBNAIL_SIZE || height > THUMBNAIL_SIZE {
                img.thumbnail(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
            } else {
                img
            };

            tn_img
                .save(&thumbnail_path)
                .context("Error saving thumbnail")?;
        }

        let db_post = dbm::NewPost {
            user_id: Some(post.user_id),
            title: post.title.map(|s| s.to_string()),
            description: post.description.map(|s| s.to_string()),
            source: post.source.map(|s| s.to_string()),
            filename: Some(post.filename.to_string()),
            size: Some(size),
            width: Some(width as i32),
            height: Some(height as i32),
            hash: Some(hash.into()),
            ext: Some(ext.as_ref().into()),
            tn_ext: Some(tn_ext.into()),
        };

        let new_post_id = self.store.create_post(&db_post, &post.tags).await?;

        Ok(new_post_id)
    }

    pub async fn get_view_post(&self, id: i32) -> Result<Option<vm::Post>, anyhow::Error> {
        let post = self.store.get_view_post(id).await?.map(vm::Post::from);

        Ok(post)
    }

    pub async fn update_post(
        &self,
        id: i32,
        request: vm::UpdatePost,
        user_id: i32,
    ) -> Result<bool, anyhow::Error> {
        let update_post = dbm_update_post_from_vm(id, request);
        let success = self.store.update_post(&update_post, user_id).await?;

        Ok(success)
    }

    pub async fn get_view_posts(
        &self,
        include_tags: Vec<&str>,
        exclude_tags: Vec<&str>,
        start_id: i32,
        limit: i32,
    ) -> Result<Vec<vm::Post>, anyhow::Error> {
        let posts = self
            .store
            .get_view_posts(&include_tags, &exclude_tags, start_id, limit)
            .await?
            .into_iter()
            .map(vm::Post::from)
            .collect();

        Ok(posts)
    }

    pub async fn calculate_pages(
        &self,
        include_tags: Vec<&str>,
        exclude_tags: Vec<&str>,
        posts_per_page: i32,
        page_count: i32,
        origin_page: Option<vm::PageInfo>,
    ) -> Result<Vec<vm::PageInfo>, anyhow::Error> {
        let pages = self
            .store
            .calculate_pages(
                &include_tags,
                &exclude_tags,
                posts_per_page,
                page_count,
                origin_page.map(dbm::PageInfo::from),
            )
            .await?;

        Ok(pages.into_iter().map(vm::PageInfo::from).collect())
    }

    pub async fn calculate_last_page(
        &self,
        include_tags: Vec<&str>,
        exclude_tags: Vec<&str>,
        posts_per_page: i32,
    ) -> Result<vm::PageInfo, anyhow::Error> {
        let page = self
            .store
            .calculate_last_page(&include_tags, &exclude_tags, posts_per_page)
            .await?;

        Ok(vm::PageInfo::from(page))
    }
}
