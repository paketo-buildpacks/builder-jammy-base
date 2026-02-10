// Dioxus-style frontend crate: UI components (dummy for smoke test).
// See https://dioxuslabs.com/
// In a real fullstack app this would hold Dioxus components.

use dioxus_app_common::APP_NAME;

/// Placeholder for frontend greeting.
pub fn greeting() -> String {
    format!("{} frontend", APP_NAME)
}
