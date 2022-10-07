use std::{
    borrow::Cow,
    path::{Path, PathBuf},
};

use anyhow::Context;
use blazebooru_common::util::{self, hash::hash_blake3_to_file_from_stream};
use blazebooru_models::local::HashedFile;
use bytes::Bytes;
use futures_core::Stream;

use super::BlazeBooruCore;

pub struct ProcessImageResult<'a> {
    pub hash: Cow<'a, str>,
    pub ext: Cow<'a, str>,
    pub original_image_path: PathBuf,
}

impl BlazeBooruCore {
    pub async fn hash_stream_to_temp_file<S: Stream<Item = Result<Bytes, E>> + Unpin, E>(
        &self,
        stream: &mut S,
    ) -> Result<HashedFile, anyhow::Error> {
        let temp_path = self.temp_path.join(uuid::Uuid::new_v4().to_string());
        let result = hash_blake3_to_file_from_stream(stream, &temp_path).await?;

        Ok(HashedFile {
            hash: result.hash,
            size: result.size as u64,
            path: temp_path,
        })
    }

    /// Process image and move it into the originals directory,
    /// or delete it if it already exists there.
    pub async fn process_image<'a>(
        &self,
        file: HashedFile,
        filename: &'a str,
        destination_path: &Path,
    ) -> Result<ProcessImageResult<'a>, anyhow::Error> {
        let (_, ext) = filename
            .rsplit_once('.')
            .context("Could not get extension from filename")?;

        let hash = file.hash;

        let original_image_filename = format!("{hash}.{ext}");
        let original_image_path = destination_path.join(original_image_filename);

        // If image does not already exist in originals path, move it there.
        if !original_image_path.exists() {
            util::async_fs::move_file(file.path, &original_image_path).await?;

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;

                tokio::fs::set_permissions(
                    &original_image_path,
                    std::fs::Permissions::from_mode(0o644),
                )
                .await?;
            }
        } else {
            // ... otherwise, delete it.
            tokio::fs::remove_file(file.path).await?;
        }

        Ok(ProcessImageResult {
            hash: hash.into(),
            ext: ext.into(),
            original_image_path,
        })
    }

    pub fn is_preserve_original(&self, ext: &str) -> bool {
        ext == "gif"
    }
}
