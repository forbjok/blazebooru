mod json;

use blazebooru_core::BlazeBooruCore;

use crate::ExportCommand;

pub(crate) async fn export(core: BlazeBooruCore, command: ExportCommand) -> Result<(), anyhow::Error> {
    match command {
        ExportCommand::Json { path } => json::export(&core, &path).await?,
    };

    Ok(())
}
