use std::path::Path;

use blazebooru_models::export as em;
use blazebooru_models::local as lm;
use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;

use blazebooru_store::transform::dbm_update_post_from_vm;

use crate::image::ProcessFileResult;
use crate::image::ProcessImageResult;

use super::BlazeBooruCore;

impl BlazeBooruCore {
    pub async fn create_post(&self, post: lm::NewPost<'_>) -> Result<i32, anyhow::Error> {
        let size = post.file.size as i32;

        // Process file
        let process_file_result = self
            .process_file(post.file, &post.filename, &self.public_original_path)
            .await?;

        let ProcessFileResult { hash, ext, .. } = &process_file_result;

        // Process image and generate thumbnail
        let ProcessImageResult { width, height, tn_ext } = self.process_image(&process_file_result).await?;

        let db_post = dbm::NewPost {
            user_id: Some(post.user_id),
            title: post.title.map(|s| s.to_string()),
            description: post.description.map(|s| s.to_string()),
            source: post.source.map(|s| s.to_string()),
            filename: Some(post.filename.to_string()),
            size: Some(size),
            width: Some(width as i32),
            height: Some(height as i32),
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
            let process_file_result = self
                .process_file(hashed_file, &post.filename, &self.public_original_path)
                .await?;

            // Process image and generate thumbnail
            self.process_image(&process_file_result).await?;
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

    pub async fn get_view_post_by_hash(&self, hash: &str) -> Result<Option<vm::Post>, anyhow::Error> {
        let post = self.store.get_view_post_by_hash(hash).await?.map(vm::Post::from);

        Ok(post)
    }

    pub async fn update_post(&self, id: i32, request: vm::UpdatePost, user_id: i32) -> Result<bool, anyhow::Error> {
        let update_post = dbm_update_post_from_vm(id, request);
        let success = self.store.update_post(&update_post, user_id).await?;

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
}
