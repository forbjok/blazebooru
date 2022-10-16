use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;

use super::BlazeBooruCore;

impl BlazeBooruCore {
    pub async fn create_post_comment(
        &self,
        comment: vm::NewPostComment,
        post_id: i32,
        user_id: Option<i32>,
    ) -> Result<vm::Comment, anyhow::Error> {
        let comment = dbm::NewPostComment {
            post_id,
            comment: comment.comment,
        };

        let comment = self.store.create_post_comment(comment, user_id).await?;

        Ok(vm::Comment::from(comment))
    }

    pub async fn get_post_comments(&self, post_id: i32) -> Result<Vec<vm::Comment>, anyhow::Error> {
        let comments = self
            .store
            .get_post_comments(post_id)
            .await?
            .into_iter()
            .map(vm::Comment::from)
            .collect();

        Ok(comments)
    }
}
