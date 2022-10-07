use std::{io, path::Path};

use tokio::fs;
use tracing::warn;

pub async fn create_parent_dir(path: impl AsRef<Path>) -> io::Result<()> {
    if let Some(parent_dir_path) = path.as_ref().parent() {
        fs::create_dir_all(parent_dir_path).await?;
    }

    Ok(())
}

/// If possible rename (move) the file, otherwise fall back to copying it and deleting the source file.
pub async fn move_file(from: impl AsRef<Path>, to: impl AsRef<Path>) -> io::Result<()> {
    if fs::rename(&from, &to).await.is_err() {
        warn!("Rename failed. Falling back to copy and remove.");
        fs::copy(&from, &to).await?;
        fs::remove_file(&from).await?;
    }

    Ok(())
}

/// If possible hard-link the file, otherwise fall back to copying it.
pub async fn hard_link_or_copy(from: impl AsRef<Path>, to: impl AsRef<Path>) -> io::Result<()> {
    if fs::hard_link(&from, &to).await.is_err() {
        warn!("Hard-link failed. Falling back to copy.");
        fs::copy(&from, &to).await?;
    }

    Ok(())
}
