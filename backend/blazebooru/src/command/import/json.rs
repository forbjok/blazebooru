use std::path::Path;

use blazebooru_core::BlazeBooruCore;

pub async fn import(core: &BlazeBooruCore, path: &Path, user_name: &str) -> Result<(), anyhow::Error> {
    blazebooru_import::json::import_json(core, path, user_name).await?;

    Ok(())
}
