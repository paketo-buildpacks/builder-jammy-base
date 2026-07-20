// Minimal Rust app for buildpack smoke test: listen on PORT and respond.
use std::env;
use std::io::Write;
use std::net::TcpListener;
use std::process;

fn main() {
    ctrlc::set_handler(|| process::exit(0)).expect("set signal handler");
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let bind = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&bind).expect("bind");
    eprintln!("jammy rust test crate starting");
    eprintln!("port={}", port);
    for mut stream in listener.incoming().flatten() {
        let _ = stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok");
    }
}
