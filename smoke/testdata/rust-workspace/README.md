# Rust workspace smoke test (Dioxus-style)

Dummy [Dioxus](https://dioxuslabs.com/)-style fullstack workspace: **common**, **frontend**, **backend**.

- `common` — shared types and utilities
- `frontend` — UI lib (placeholder)
- `backend` — HTTP server binary (runnable)

## Build with pack

Build only the backend binary (use `BP_RUST_PACKAGE` for a multi-crate workspace):

```bash
pack build rust-workspace-app \
  --path smoke/testdata/rust-workspace \
  --builder octopilot-builder-jammy-base \
  --env BP_RUST_PACKAGE=dioxus-app-backend
```

Then run:

```bash
docker run --rm -e PORT=8080 -p 8080:8080 rust-workspace-app /workspace/bin/dioxus-app-backend
```
