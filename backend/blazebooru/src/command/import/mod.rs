mod json;

use blazebooru_core::BlazeBooruCore;

use crate::ImportCommand;

pub(crate) async fn import(core: BlazeBooruCore, command: ImportCommand) -> Result<(), anyhow::Error> {
    match command {
        ImportCommand::Json { path, user_name } => json::import(&core, &path, &user_name).await?,
    };

    Ok(())
}
