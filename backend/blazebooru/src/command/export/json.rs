use std::path::Path;

use blazebooru_core::BlazeBooruCore;

pub async fn export(core: &BlazeBooruCore, path: &Path) -> Result<(), anyhow::Error> {
    blazebooru_export::json::export_json(path, core).await?;

    Ok(())
}
