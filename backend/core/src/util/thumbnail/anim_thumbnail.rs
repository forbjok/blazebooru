use std::{path::Path, process::Command};

use anyhow::{Context, anyhow};

use super::{ThumbnailGenerator, ThumbnailQuality};

#[derive(Debug)]
struct ThumbnailSpec<'a> {
    dst_path: &'a Path,
    width: u32,
    height: u32,
}

#[derive(Debug)]
pub struct AnimatedThumbnailGenerator<'a> {
    source: &'a Path,
    quality: ThumbnailQuality,
    thumbnails: Vec<ThumbnailSpec<'a>>,
}

impl<'a> AnimatedThumbnailGenerator<'a> {
    pub fn new(source: &'a Path, quality: ThumbnailQuality) -> Self {
        Self {
            source,
            quality,
            thumbnails: Vec::new(),
        }
    }
}

impl<'a> ThumbnailGenerator<'a> for AnimatedThumbnailGenerator<'a> {
    fn add(&mut self, dst_path: &'a Path, width: u32, height: u32) {
        self.thumbnails.push(ThumbnailSpec {
            dst_path,
            width,
            height,
        });
    }

    fn generate(&self) -> Result<(), anyhow::Error> {
        if self.thumbnails.is_empty() {
            return Ok(());
        }

        let quality_args = match self.quality {
            ThumbnailQuality::Post => ["-compression_level", "4", "-quality", "40"],
        };

        for vp in self.thumbnails.iter() {
            let filter_arg = format!(
                r"scale=min({}\,iw):min({}\,ih):force_original_aspect_ratio=decrease,format=yuva420p",
                vp.width, vp.height
            );

            let status = Command::new("ffmpeg")
                .args(["-hide_banner", "-y"])
                .arg("-i")
                .arg(self.source)
                .args(["-map_metadata", "-1", "-filter:v", &filter_arg])
                .args(quality_args)
                .args(["-loop", "0"])
                .arg(vp.dst_path)
                .status()
                .context("Executing ffmpeg")?;

            if !status.success() {
                return Err(anyhow!("Error generating animated thumbnail"));
            }
        }

        Ok(())
    }
}
