use std::{
    borrow::Cow,
    io::Read,
    path::{Path, PathBuf},
};

use anyhow::Context;
use blazebooru_common::util::hash::hash_blake3_to_file_from_file;
use bytes::Bytes;
use futures_core::Stream;
use once_cell::sync::Lazy;

use blazebooru_common::util;
use blazebooru_models::local::HashedFile;

use super::BlazeBooruCore;
use blazebooru_common::util::hash::hash_blake3_to_file_from_stream;

pub const IMAGE_EXT: &str = "webp";
pub const ANIM_IMAGE_EXT: &str = "webp";
pub const VIDEO_EXT: &str = "webm";

pub struct ProcessFileResult<'a> {
    pub hash: String,
    pub original_ext: Cow<'a, str>,
    pub original_file_path: PathBuf,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileKind {
    Image,
    AnimatedImage,
    Video,
}

static RE_IS_ANIMATED_WEBP: Lazy<regex::bytes::Regex> =
    Lazy::new(|| regex::bytes::Regex::new(r"^(?s-u:RIFF.{4}WEBPVP8X.{14}ANIM)").unwrap());

impl BlazeBooruCore {
    pub async fn hash_file_to_temp_file(&self, path: &Path) -> Result<HashedFile, anyhow::Error> {
        let temp_path = self.temp_path.join(uuid::Uuid::new_v4().to_string());
        let result = hash_blake3_to_file_from_file(path, &temp_path).await?;

        Ok(HashedFile {
            hash: result.hash,
            path: temp_path,
            size: result.size,
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
            path: temp_path,
            size: result.size,
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
        let (_, original_ext) = filename
            .rsplit_once('.')
            .context("Could not get extension from filename")?;

        let hash = file.hash;

        let original_image_filename = format!("{hash}.{original_ext}");
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
            hash,
            original_ext: original_ext.into(),
            original_file_path: original_image_path,
        })
    }

    pub fn identify_file(&self, ext: &str, path: &Path) -> FileKind {
        match ext {
            "gif" => FileKind::AnimatedImage,
            "webp" => {
                if is_animated_webp(path) {
                    FileKind::AnimatedImage
                } else {
                    FileKind::Image
                }
            }
            "webm" | "mp4" | "m4v" => FileKind::Video,
            _ => FileKind::Image,
        }
    }
}

fn is_animated_webp(path: &Path) -> bool {
    let Ok(mut file) = std::fs::File::open(path) else {
        return false;
    };

    let mut buf: [u8; 34] = [0; 34];
    if file.read_exact(&mut buf).is_err() {
        return false;
    }

    if !RE_IS_ANIMATED_WEBP.is_match(&buf) {
        return false;
    }

    true
}
