use std::{cmp, path::Path};

use anyhow::Context;

use super::ThumbnailGenerator;

#[derive(Debug)]
struct ThumbnailSpec<'a> {
    dst_path: &'a Path,
    width: u32,
    height: u32,
}

#[derive(Debug)]
pub struct StaticThumbnailGenerator<'a> {
    source: &'a Path,
    thumbnails: Vec<ThumbnailSpec<'a>>,
}

impl<'a> StaticThumbnailGenerator<'a> {
    pub fn new(source: &'a Path) -> Self {
        Self {
            source,
            thumbnails: Vec::new(),
        }
    }
}

impl<'a> ThumbnailGenerator<'a> for StaticThumbnailGenerator<'a> {
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

        // Open image file
        let img = image::open(self.source)?;

        let o_width = img.width();
        let o_height = img.height();

        for tn in self.thumbnails.iter() {
            let tn_width = cmp::min(tn.width, o_width);
            let tn_height = cmp::min(tn.height, o_height);

            let tn_img = img.thumbnail(tn_width, tn_height);
            tn_img
                .into_rgba8()
                .save(tn.dst_path)
                .context("Error saving thumbnail")?;
        }

        Ok(())
    }
}
