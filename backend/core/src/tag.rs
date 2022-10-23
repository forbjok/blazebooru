use blazebooru_models::view as vm;
use blazebooru_store::models as dbm;

use super::BlazeBooruCore;

impl BlazeBooruCore {
    pub async fn get_view_tag(&self, id: i32) -> Result<Option<vm::Tag>, anyhow::Error> {
        let tag = self.store.get_view_tag(id).await?.map(vm::Tag::from);

        Ok(tag)
    }

    pub async fn get_view_tags(&self) -> Result<Vec<vm::Tag>, anyhow::Error> {
        let tags = self
            .store
            .get_view_tags()
            .await?
            .into_iter()
            .map(vm::Tag::from)
            .collect();

        Ok(tags)
    }

    pub async fn update_tag(&self, id: i32, request: vm::UpdateTag, user_id: i32) -> Result<bool, anyhow::Error> {
        let update_tag = dbm::UpdateTag::from(request);
        let success = self.store.update_tag(id, &update_tag, user_id).await?;

        Ok(success)
    }
}
