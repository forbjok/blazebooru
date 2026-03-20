use std::borrow::Cow;
use std::path::Path;

use anyhow::Context as _;
use anyhow::anyhow;

use blazebooru_models::export as em;
use blazebooru_models::local as lm;
use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;
use blazebooru_store::transform::dbm_update_post_from_vm;

use crate::file::ProcessFileResult;
use crate::util::image::{ImageMetadata, get_image_metadata};
use crate::util::thumbnail::{
    AnimatedThumbnailGenerator, StaticThumbnailGenerator, ThumbnailGenerator, ThumbnailQuality,
};
use crate::{ANIM_IMAGE_EXT, FileKind, IMAGE_EXT};

use super::BlazeBooruCore;

const THUMBNAIL_WIDTH: u32 = 200;
const THUMBNAIL_HEIGHT: u32 = 200;

pub struct GeneratePostThumbnailResult<'a> {
    pub ext: Cow<'a, str>,
    pub tn_ext: Cow<'a, str>,
}

impl BlazeBooruCore {
    pub async fn create_post(&self, post: lm::NewPost<'_>) -> Result<i32, anyhow::Error> {
        let size = post.file.size as i32;

        // Process file
        let ProcessFileResult {
            hash,
            original_ext,
            original_file_path,
        } = self
            .process_file(post.file, &post.filename, &self.public_original_path)
            .await?;

        // Check whether there are existing posts with the same hash
        let identical_posts = self.store.get_posts_by_hash(&hash).await?;
        if let Some(identical_post) = identical_posts.first() {
            return Err(anyhow!(
                "Another post with the same file already exists with ID: {}",
                identical_post.id,
            ));
        }

        // Generate thumbnail
        let GeneratePostThumbnailResult { ext, tn_ext } = self
            .generate_post_thumbnail(&original_file_path, &hash, &original_ext, false)
            .await?;

        let ImageMetadata { width, height } = get_image_metadata(&original_file_path)?;

        let db_post = dbm::NewPost {
            user_id: Some(post.user_id),
            title: post.title.map(|s| s.to_string()),
            description: post.description.map(|s| s.to_string()),
            source: post.source.map(|s| s.to_string()),
            filename: Some(post.filename.to_string()),
            size: Some(size),
            width: Some(width),
            height: Some(height),
            hash: Some(hash.to_string()),
            ext: Some(ext.as_ref().into()),
            tn_ext: Some(tn_ext.into()),
        };

        let new_post_id = self.store.create_post(&db_post, &post.tags).await?;

        Ok(new_post_id)
    }

    pub async fn import_post(&self, post: em::Post, user_id: i32, file: Option<&Path>) -> Result<i32, anyhow::Error> {
        if let Some(path) = file {
            let hashed_file = self.hash_file_to_temp_file(path).await?;

            // Process file
            let ProcessFileResult {
                hash,
                original_ext,
                original_file_path,
            } = self
                .process_file(hashed_file, &post.filename, &self.public_original_path)
                .await?;

            // Generate thumbnail
            self.generate_post_thumbnail(&original_file_path, &hash, &original_ext, false)
                .await?;
        }

        let db_post = dbm::NewPost {
            user_id: Some(user_id),
            title: post.title,
            description: post.description,
            source: post.source,
            filename: Some(post.filename),
            size: Some(post.size),
            width: Some(post.width),
            height: Some(post.height),
            hash: Some(post.hash),
            ext: Some(post.ext),
            tn_ext: Some(post.tn_ext),
        };

        let tags: Vec<_> = post.tags.iter().map(|t| t.as_str()).collect();

        let new_post_id = self.store.create_post(&db_post, &tags).await?;

        Ok(new_post_id)
    }

    pub async fn get_view_post(&self, id: i32) -> Result<Option<vm::Post>, anyhow::Error> {
        let post = self.store.get_view_post(id).await?.map(vm::Post::from);

        Ok(post)
    }

    pub async fn update_post(&self, id: i32, request: vm::UpdatePost, user_id: i32) -> Result<bool, anyhow::Error> {
        let update_post = dbm_update_post_from_vm(id, request);
        let success = self.store.update_post(&update_post, user_id).await?;

        Ok(success)
    }

    pub async fn delete_post(&self, id: i32, user_id: i32) -> Result<bool, anyhow::Error> {
        let success = self.store.delete_post(id, user_id).await?;

        Ok(success)
    }

    pub async fn get_export_posts(
        &self,
        include_tags: Vec<String>,
        exclude_tags: Vec<String>,
        start_id: i32,
        limit: i32,
    ) -> Result<Vec<em::Post>, anyhow::Error> {
        let posts = self
            .store
            .get_view_posts(&include_tags, &exclude_tags, start_id, limit)
            .await?
            .into_iter()
            .map(em::Post::from)
            .collect();

        Ok(posts)
    }

    pub async fn get_view_posts(
        &self,
        include_tags: Vec<String>,
        exclude_tags: Vec<String>,
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

    /// Generate thumbnail
    pub async fn generate_post_thumbnail<'a>(
        &self,
        original_image_path: &Path,
        hash: &str,
        ext: &'a str,
        overwrite: bool,
    ) -> Result<GeneratePostThumbnailResult<'a>, anyhow::Error> {
        let file_kind = self.identify_file(ext, original_image_path);

        // Animated WebP can't be transcoded, as ffmpeg doesn't support decoding it
        let preserve_original = file_kind == FileKind::AnimatedImage && ext == "webp";

        let tn_ext = match file_kind {
            FileKind::Image => IMAGE_EXT,
            FileKind::AnimatedImage | FileKind::Video => ANIM_IMAGE_EXT,
        };

        let thumbnail_filename = format!("{hash}.{tn_ext}");
        let thumbnail_path = self.public_thumbnail_path.join(thumbnail_filename);

        let mut tn_gen: Box<dyn ThumbnailGenerator> = match file_kind {
            FileKind::Image => Box::new(StaticThumbnailGenerator::new(original_image_path)),
            FileKind::AnimatedImage | FileKind::Video => Box::new(AnimatedThumbnailGenerator::new(
                original_image_path,
                ThumbnailQuality::Post,
            )),
        };

        // If thumbnail does not already exist, create it.
        let thumbnail_exists = thumbnail_path.exists();
        if overwrite || !thumbnail_exists {
            if preserve_original {
                if thumbnail_exists {
                    tokio::fs::remove_file(&thumbnail_path).await?;
                }

                // If preserving original, simply create a hard link to the original file
                tokio::fs::hard_link(&original_image_path, &thumbnail_path).await?;
            } else {
                tn_gen.add(&thumbnail_path, THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT);
            }
        }

        tn_gen.generate().context("Error generating post image and thumbnail")?;

        Ok(GeneratePostThumbnailResult {
            ext: ext.into(),
            tn_ext: tn_ext.into(),
        })
    }
}
