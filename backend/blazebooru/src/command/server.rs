use std::env;

use anyhow::Context;

use blazebooru_core::{config::BlazeBooruConfig, BlazeBooruCore};

use crate::{auth::BlazeBooruAuth, server::BlazeBooruServer};

pub async fn server(config: BlazeBooruConfig, core: BlazeBooruCore, serve_files: bool) -> Result<(), anyhow::Error> {
    let jwt_secret = env::var("BLAZEBOORU_JWT_SECRET")
        .ok()
        .or_else(|| config.jwt_secret.clone())
        .context("BLAZEBOORU_JWT_SECRET is not set")?;

    let auth = BlazeBooruAuth::new(jwt_secret.as_bytes());

    let server = BlazeBooruServer {
        config,
        auth,
        core,
        serve_files,
    };

    let shutdown = || async {
        tokio::signal::ctrl_c().await.expect("Error awaiting Ctrl-C signal");
    };

    server.run_server(shutdown()).await?;

    Ok(())
}
