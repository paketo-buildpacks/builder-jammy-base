// Dioxus-style shared crate: types and utilities for frontend + backend.
// See https://dioxuslabs.com/

use serde::{Deserialize, Serialize};

/// Shared app name for responses.
pub const APP_NAME: &str = "dioxus-app";

/// Login form payload (shared by frontend and backend API).
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct LoginForm {
    pub username: String,
    pub password: String,
}
