use std::env;

use anyhow::Context;
use clap::Parser;
use tracing::{debug, info};
use tracing_subscriber::{EnvFilter, FmtSubscriber};

use blazebooru_core::BlazeBooruCore;

use crate::{auth::BlazeBooruAuth, server::BlazeBooruServer};

mod auth;
mod server;

#[derive(Debug, Parser)]
#[clap(name = "BlazeBooru Server", version = env!("CARGO_PKG_VERSION"), author = env!("CARGO_PKG_AUTHORS"))]
struct Opt {
    #[clap(long = "migrate", help = "Run database migration on startup")]
    migrate: bool,
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opt = Opt::parse();

    // Initialize logging
    initialize_logging();

    debug!("Debug logging enabled.");

    dotenv::dotenv().ok();

    let jwt_secret =
        env::var("BLAZEBOORU_JWT_SECRET").context("BLAZEBOORU_JWT_SECRET is not set")?;

    let auth = BlazeBooruAuth::new(jwt_secret.as_bytes());
    let core = BlazeBooruCore::new()?;

    if opt.migrate {
        info!("Running database migrations...");
        core.migrate().await?;
    }

    let server = BlazeBooruServer::new(auth, core).context("Error creating server")?;

    let shutdown = || async {
        tokio::signal::ctrl_c()
            .await
            .expect("Error awaiting Ctrl-C signal");
    };

    server.run_server(shutdown()).await?;

    Ok(())
}

fn initialize_logging() {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .finish();

    tracing::subscriber::set_global_default(subscriber)
        .expect("Setting default tracing subscriber failed!");
}
