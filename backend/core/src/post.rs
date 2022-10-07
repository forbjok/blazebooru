use anyhow::Context;

use blazebooru_models::local as lm;
use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;

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

        let post = dbm::NewPost {
            user_id: Some(post.user_id),
            title: post.title.map(|s| s.to_string()),
            description: post.description.map(|s| s.to_string()),
            filename: Some(post.filename.to_string()),
            size: Some(size),
            width: Some(width as i32),
            height: Some(height as i32),
            hash: Some(hash.into()),
            ext: Some(ext.as_ref().into()),
            tn_ext: Some(tn_ext.into()),
        };

        let post = self.store.create_post(&post).await?;

        Ok(post.id.unwrap())
    }

    pub async fn get_view_post(&self, id: i32) -> Result<Option<vm::Post>, anyhow::Error> {
        let post = self.store.get_view_post(id).await?.map(vm::Post::from);

        Ok(post)
    }

    pub async fn get_view_posts(&self) -> Result<Vec<vm::Post>, anyhow::Error> {
        let posts = self
            .store
            .get_view_posts()
            .await?
            .into_iter()
            .map(vm::Post::from)
            .collect();

        Ok(posts)
    }
}
