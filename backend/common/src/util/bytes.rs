use std::{io::Read, path::Path};

use anyhow::Context;
use bytes::{Buf, Bytes};
use tokio::{fs, io::AsyncWriteExt};

const BUFFER_SIZE: usize = 65536;

/// Read bytes from Bytes and write to a file
pub async fn write_bytes_to_file(bytes: Bytes, path: &Path) -> Result<usize, anyhow::Error> {
    let mut file = fs::File::create(path)
        .await
        .with_context(|| format!("Opening file for writing: {}", path.display()))?;

    let mut buf = [0u8; BUFFER_SIZE];

    let mut total_size = 0;

    let mut reader = bytes.reader();
    loop {
        let bytes = reader.read(&mut buf)?;
        if bytes == 0 {
            break;
        }

        total_size += bytes;

        let buf = &buf[..bytes];
        file.write_all(buf).await?;
    }

    Ok(total_size)
}
