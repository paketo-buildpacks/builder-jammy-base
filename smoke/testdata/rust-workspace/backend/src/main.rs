// Dioxus fullstack backend: serves login form (SSR) and login API.
// See https://dioxuslabs.com/

#[cfg(feature = "server")]
mod server;

#[cfg(feature = "server")]
fn main() {
    server::run();
}

#[cfg(not(feature = "server"))]
fn main() {
    eprintln!("Build with --features server to run the backend server");
}
