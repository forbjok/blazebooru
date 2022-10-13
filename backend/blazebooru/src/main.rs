use std::env;

use clap::Parser;
use tracing::{debug, info};
use tracing_subscriber::{EnvFilter, FmtSubscriber};

use blazebooru_core::BlazeBooruCore;

mod auth;
mod command;
mod deserialize;
mod server;

#[derive(Debug, Parser)]
#[clap(name = "BlazeBooru Server", version = env!("CARGO_PKG_VERSION"), author = env!("CARGO_PKG_AUTHORS"))]
struct Opt {
    #[clap(long = "migrate", help = "Run database migration on startup")]
    migrate: bool,

    #[clap(subcommand)]
    command: Command,
}

#[derive(Debug, Parser)]
enum Command {
    #[clap(about = "Run BlazeBooru server")]
    Server,
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opt = Opt::parse();

    // Initialize logging
    initialize_logging();

    debug!("Debug logging enabled.");

    dotenv::dotenv().ok();

    let core = BlazeBooruCore::new()?;

    if opt.migrate {
        info!("Running database migrations...");
        core.migrate().await?;
    }

    match opt.command {
        Command::Server => command::server(core).await?,
    };

    Ok(())
}

fn initialize_logging() {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("Setting default tracing subscriber failed!");
}
