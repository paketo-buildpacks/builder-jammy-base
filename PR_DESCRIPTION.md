## PR Description: Custom Builder with Rust Support

### Problem
To support our Rust applications (`sample-static-rust-axum`) and modernize our build stack, we required a custom builder based on Ubuntu 22.04 (Jammy). Standard builders did not include our specific Rust buildpack configuration out-of-the-box.

### Changes
-   **New Builder**: Created `builder-jammy-base` derived from the Jammy stack.
-   **Rust Integration**: Included the custom `octopilot/rust` buildpack in the order group.
-   **Optimization**: Configured for efficient layer caching in our CI/CD environment.

### Verification
Successfully used this builder to build the `sample-static-rust-axum` API component via `octopilot-pipeline-tools` (`op`). The resulting image runs correctly in both local and Kubernetes environments.
