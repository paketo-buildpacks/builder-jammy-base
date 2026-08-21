// Dioxus-style frontend crate: UI components. See https://dioxuslabs.com/

use dioxus::prelude::*;
use dioxus_app_common::APP_NAME;

/// Placeholder for frontend greeting.
pub fn greeting() -> String {
    format!("{} frontend", APP_NAME)
}

/// Login form component: renders a form that POSTs to /api/login.
#[component]
pub fn LoginFormComponent() -> Element {
    rsx! {
        div {
            class: "login-form",
            h2 { "Sign in to {APP_NAME}" }
            form {
                action: "/api/login",
                method: "post",
                div {
                    label { r#for: "username", "Username" }
                    input {
                        r#type: "text",
                        id: "username",
                        name: "username",
                        placeholder: "Enter username",
                        required: true,
                    }
                }
                div {
                    label { r#for: "password", "Password" }
                    input {
                        r#type: "password",
                        id: "password",
                        name: "password",
                        placeholder: "Enter password",
                        required: true,
                    }
                }
                button { r#type: "submit", "Login" }
            }
        }
    }
}
