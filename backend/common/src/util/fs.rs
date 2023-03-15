use std::fs;
use std::{io, path::Path};

pub fn create_parent_dir(path: impl AsRef<Path>) -> io::Result<()> {
    if let Some(parent_dir_path) = path.as_ref().parent() {
        fs::create_dir_all(parent_dir_path)?;
    }

    Ok(())
}
