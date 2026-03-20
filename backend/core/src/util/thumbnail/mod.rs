mod anim_thumbnail;
mod static_thumbnail;

use std::path::Path;

pub use self::anim_thumbnail::*;
pub use self::static_thumbnail::*;

pub trait ThumbnailGenerator<'a>: Send {
    /// Add thumbnail spec to be generated
    fn add(&mut self, dst_path: &'a Path, width: u32, height: u32);

    /// Generate thumbnails
    fn generate(&self) -> Result<(), anyhow::Error>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThumbnailQuality {
    Post,
}
