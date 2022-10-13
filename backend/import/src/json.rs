use std::{fs, path::Path};

use anyhow::Context;

use blazebooru_core::BlazeBooruCore;
use blazebooru_models::export as em;

pub async fn import_json(core: &BlazeBooruCore, path: &Path, user_name: &str) -> Result<(), anyhow::Error> {
    let user = core
        .get_user_by_name(user_name)
        .await
        .context("Error getting user ID")?
        .context("User does not exist")?;
    let user_id = user.id;

    let file = fs::File::open(path).context("Error opening JSON file")?;

    let posts: Vec<em::Post> = serde_json::from_reader(file).context("Error deserializing from JSON file")?;

    for post in posts.into_iter() {
        // Change user ID
        core.import_post(post, user_id, None).await?;
    }

    Ok(())
}
