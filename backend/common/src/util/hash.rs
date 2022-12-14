use std::{io::Read, path::Path};

use anyhow::Context;
use bytes::{Buf, Bytes};
use futures_core::Stream;
use futures_util::StreamExt;
use tokio::{
    fs,
    io::{AsyncReadExt, AsyncWriteExt},
};

const BUFFER_SIZE: usize = 65536;

pub struct HashResult {
    pub hash: String,
    pub size: usize,
}

/// Read bytes from Bytes, calculate hash and write to a file
pub async fn hash_blake3_to_file_from_file(src_path: &Path, dst_path: &Path) -> Result<HashResult, anyhow::Error> {
    let mut src_file = fs::File::open(src_path)
        .await
        .with_context(|| format!("Opening source file: {}", src_path.display()))?;

    let mut dst_file = fs::File::create(dst_path)
        .await
        .with_context(|| format!("Creating destination file: {}", dst_path.display()))?;

    let mut hasher = blake3::Hasher::new();

    let mut buf = [0u8; BUFFER_SIZE];

    let mut total_size = 0;

    loop {
        let bytes = src_file.read(&mut buf).await?;
        if bytes == 0 {
            break;
        }

        total_size += bytes;

        let buf = &buf[..bytes];
        hasher.update(buf);
        dst_file.write_all(buf).await?;
    }

    let hash = hasher.finalize();

    Ok(HashResult {
        hash: hash.to_hex().to_string(),
        size: total_size,
    })
}

/// Read bytes from stream, calculate hash and write to a file
pub async fn hash_blake3_to_file_from_stream<S: Stream<Item = Result<Bytes, E>> + Unpin, E>(
    stream: &mut S,
    path: &Path,
) -> Result<HashResult, anyhow::Error> {
    let mut file = fs::File::create(path)
        .await
        .with_context(|| format!("Opening file for writing: {}", path.display()))?;

    let mut hasher = blake3::Hasher::new();

    let mut buf = [0u8; BUFFER_SIZE];

    let mut total_size = 0;
    while let Some(Ok(bytes)) = stream.next().await {
        let mut reader = bytes.reader();

        loop {
            let bytes = reader.read(&mut buf)?;
            if bytes == 0 {
                break;
            }

            total_size += bytes;

            let buf = &buf[..bytes];
            hasher.update(buf);
            file.write_all(buf).await?;
        }
    }

    let hash = hasher.finalize();

    Ok(HashResult {
        hash: hash.to_hex().to_string(),
        size: total_size,
    })
}
