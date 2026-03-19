// Dioxus-style frontend binary: minimal HTTP server (smoke test).
// See https://dioxuslabs.com/
use std::env;
use std::io::Write;
use std::net::TcpListener;
use std::process;

use dioxus_app_frontend::greeting;

fn main() {
    ctrlc::set_handler(|| process::exit(0)).expect("set signal handler");
    let port = env::var("PORT").unwrap_or_else(|_| "8081".to_string());
    let bind = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&bind).expect("bind");
    eprintln!("{} starting", greeting());
    eprintln!("port={}", port);
    for mut stream in listener.incoming().flatten() {
        let _ = stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nUI\n");
    }
}
