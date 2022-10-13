use std::{
    borrow::Cow,
    path::{Path, PathBuf},
};

use anyhow::Context;
use blazebooru_common::util::{
    self,
    hash::{hash_blake3_to_file_from_file, hash_blake3_to_file_from_stream},
};
use blazebooru_models::local::HashedFile;
use bytes::Bytes;
use futures_core::Stream;
use image::GenericImageView;

use super::BlazeBooruCore;

pub struct ProcessFileResult<'a> {
    pub hash: Cow<'a, str>,
    pub ext: Cow<'a, str>,
    pub original_image_path: PathBuf,
}

pub struct ProcessImageResult<'a> {
    pub width: u32,
    pub height: u32,
    pub tn_ext: Cow<'a, str>,
}

const THUMBNAIL_SIZE: u32 = 200;

impl BlazeBooruCore {
    pub async fn hash_file_to_temp_file(&self, path: &Path) -> Result<HashedFile, anyhow::Error> {
        let temp_path = self.temp_path.join(uuid::Uuid::new_v4().to_string());
        let result = hash_blake3_to_file_from_file(path, &temp_path).await?;

        Ok(HashedFile {
            hash: result.hash,
            size: result.size as u64,
            path: temp_path,
        })
    }

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

    /// Process file and move it into the originals directory,
    /// or delete it if it already exists there.
    pub async fn process_file<'a>(
        &self,
        file: HashedFile,
        filename: &'a str,
        destination_path: &Path,
    ) -> Result<ProcessFileResult<'a>, anyhow::Error> {
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

                tokio::fs::set_permissions(&original_image_path, std::fs::Permissions::from_mode(0o644)).await?;
            }
        } else {
            // ... otherwise, delete it.
            tokio::fs::remove_file(file.path).await?;
        }

        Ok(ProcessFileResult {
            hash: hash.into(),
            ext: ext.into(),
            original_image_path,
        })
    }

    /// Process image, extract relevant information
    /// and generate thumbnail.
    pub async fn process_image<'a>(
        &self,
        ProcessFileResult {
            hash,
            original_image_path,
            ..
        }: &ProcessFileResult<'a>,
    ) -> Result<ProcessImageResult<'a>, anyhow::Error> {
        // Open image file
        let img = image::open(&original_image_path)?;
        let (width, height) = img.dimensions();

        // Generate thumbnail
        let tn_ext = "jpg";
        let thumbnail_filename = format!("{hash}.{tn_ext}");
        let thumbnail_path = self.public_thumbnail_path.join(thumbnail_filename);

        // If thumbnail does not already exist, create it.
        let thumbnail_exists = thumbnail_path.exists();
        if !thumbnail_exists {
            // Only resize image if it exceeds the thumbnail dimensions
            let tn_img = if width > THUMBNAIL_SIZE || height > THUMBNAIL_SIZE {
                img.thumbnail(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
            } else {
                img
            };

            tn_img.save(&thumbnail_path).context("Error saving thumbnail")?;
        }

        Ok(ProcessImageResult {
            width,
            height,
            tn_ext: tn_ext.into(),
        })
    }

    pub fn is_preserve_original(&self, ext: &str) -> bool {
        ext == "gif"
    }
}
