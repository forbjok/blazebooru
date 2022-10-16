use std::{env, path::PathBuf};

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
    #[clap(about = "Export data")]
    Export {
        #[clap(subcommand)]
        command: ExportCommand,
    },

    #[clap(about = "Import data")]
    Import {
        #[clap(subcommand)]
        command: ImportCommand,
    },

    #[clap(about = "Run BlazeBooru server")]
    Server {
        #[clap(long = "serve-files", help = "Serve public files (recommended only for development)")]
        serve_files: bool,
    },
}

#[derive(Debug, Parser)]
enum ExportCommand {
    #[clap(about = "Export data to JSON file")]
    Json {
        #[clap(help = "Path to JSON file")]
        path: PathBuf,
    },
}

#[derive(Debug, Parser)]
enum ImportCommand {
    #[clap(about = "Import data from JSON file")]
    Json {
        #[clap(help = "Path to JSON file")]
        path: PathBuf,
        #[clap(long = "user-name", short = 'u', help = "Path to JSON file")]
        user_name: String,
    },
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
        Command::Export { command } => command::export(core, command).await?,
        Command::Import { command } => command::import(core, command).await?,
        Command::Server { serve_files } => command::server(core, serve_files).await?,
    };

    Ok(())
}

fn initialize_logging() {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("Setting default tracing subscriber failed!");
}
