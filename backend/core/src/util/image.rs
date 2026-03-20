use std::{path::Path, process::Command};

use anyhow::{Context as _, anyhow};
use serde_derive::Deserialize;

pub struct ImageMetadata {
    pub width: i32,
    pub height: i32,
}

pub fn get_image_metadata(path: &Path) -> anyhow::Result<ImageMetadata> {
    #[derive(Deserialize)]
    struct FfProbeStream {
        width: Option<i32>,
        height: Option<i32>,
    }

    #[derive(Deserialize)]
    struct FfProbeInfo {
        streams: Vec<FfProbeStream>,
    }

    let output = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "stream=width,height",
            "-of",
            "json=compact=1",
        ])
        .arg(path)
        .output()
        .context("Executing ffprobe")?;

    let info: FfProbeInfo = serde_json::from_slice(&output.stdout).context("Error deserializing ffprobe output")?;

    for stream in info.streams.into_iter() {
        let FfProbeStream {
            width: Some(width),
            height: Some(height),
        } = stream
        else {
            continue;
        };

        return Ok(ImageMetadata { width, height });
    }

    Err(anyhow!("No valid stream found"))
}
