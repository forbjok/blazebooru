use std::{fs, path::Path};

use anyhow::Context;

use blazebooru_core::BlazeBooruCore;

pub async fn export_json(path: &Path, core: &BlazeBooruCore) -> Result<(), anyhow::Error> {
    let posts = core
        .get_export_posts(vec![], vec![], i32::MAX, i32::MAX)
        .await
        .context("Error retrieving posts")?;

    let file = fs::File::create(path).context("Error creating JSON file")?;
    serde_json::to_writer_pretty(file, &posts).context("Error serializing to JSON file")?;

    Ok(())
}
