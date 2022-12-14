use std::env;

use anyhow::Context;

use blazebooru_core::BlazeBooruCore;

use crate::{auth::BlazeBooruAuth, server::BlazeBooruServer};

pub async fn server(core: BlazeBooruCore, serve_files: bool) -> Result<(), anyhow::Error> {
    let jwt_secret = env::var("BLAZEBOORU_JWT_SECRET").context("BLAZEBOORU_JWT_SECRET is not set")?;

    let auth = BlazeBooruAuth::new(jwt_secret.as_bytes());
    let server = BlazeBooruServer {
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
