// Dioxus fullstack server: serves the app (login form) and API.
#[cfg(feature = "server")]
pub fn run() {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("tokio runtime")
        .block_on(run_inner())
}

#[cfg(feature = "server")]
async fn run_inner() {
    use dioxus::prelude::*;
    use dioxus::server::axum::routing::post;
    use dioxus::server::axum::{extract::Form, serve};
    use dioxus_app_common::{APP_NAME, LoginForm};
    use dioxus_app_frontend::LoginFormComponent;
    use std::env;
    use std::net::SocketAddr;

    ctrlc::set_handler(|| std::process::exit(0)).expect("set signal handler");

    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));

    eprintln!("{} backend starting", APP_NAME);
    eprintln!("port={}", port);

    fn app() -> Element {
        rsx! {
            div {
                class: "app",
                h1 { "Welcome to {APP_NAME}" }
                LoginFormComponent {}
            }
        }
    }

    async fn login_handler(Form(form): Form<LoginForm>) -> String {
        if form.username == "admin" && form.password == "password" {
            format!("Login successful for {}", form.username)
        } else {
            "Invalid credentials".to_string()
        }
    }

    let router = dioxus::server::router(app)
        .route("/api/login", post(login_handler));

    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    serve(listener, router.into_make_service())
        .await
        .expect("serve");
}

