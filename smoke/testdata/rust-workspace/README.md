# Rust workspace smoke test (Dioxus-style)

[Dioxus](https://dioxuslabs.com/)-style fullstack workspace: **common**, **frontend**, **backend**.

- `common` — shared types (e.g. `LoginForm`) and utilities
- `frontend` — Dioxus components (login form) + standalone binary
- `backend` — Dioxus fullstack server: SSR login form + POST `/api/login`

**Backend** serves a login form (SSR) and handles login via POST `/api/login`. Test credentials: `admin` / `password`.

**Two binaries:** `dioxus-app-backend` (fullstack), `dioxus-app-frontend` (standalone). Use `BP_RUST_PACKAGE` to build one.

## Build with pack

### Monolith (one image, all binaries)

Single step builds both backend and frontend into one image. Process types: `web` (first), `backend`, `frontend`.

```bash
pack build rust-workspace-monolith \
  --path smoke/testdata/rust-workspace \
  --builder octopilot-builder-jammy-base \
  --env BP_RUST_FEATURES=dioxus-app-backend/server
```

Run backend: `docker run --rm -e PORT=8080 -p 8080:8080 rust-workspace-monolith /workspace/bin/dioxus-app-backend`

Run frontend: `docker run --rm -e PORT=8081 -p 8081:8081 rust-workspace-monolith /workspace/bin/dioxus-app-frontend`

Platforms (Cloud Foundry, k8s, etc.) can use process types `web`, `backend`, or `frontend` from the built image.

### Single package (one image per binary)

Build the backend (fullstack with login form + API):

```bash
pack build rust-workspace-backend \
  --path smoke/testdata/rust-workspace \
  --builder octopilot-builder-jammy-base \
  --env BP_RUST_PACKAGE=dioxus-app-backend \
  --env BP_RUST_FEATURES=dioxus-app-backend/server
```

Build the frontend (standalone binary):

```bash
pack build rust-workspace-frontend \
  --path smoke/testdata/rust-workspace \
  --builder octopilot-builder-jammy-base \
  --env BP_RUST_PACKAGE=dioxus-app-frontend
```

## Run locally (cargo)

```bash
# Backend (needs --features server; requires public/ dir)
cargo run --release --features server -p dioxus-app-backend

# In another terminal:
curl -s http://localhost:8080           # Login form (HTML)
curl -s -X POST -d "username=admin&password=password" http://localhost:8080/api/login  # Login API
```

## Run (Docker)

```bash
# Backend (default PORT 8080)
docker run --rm -e PORT=8080 -p 8080:8080 rust-workspace-backend /workspace/bin/dioxus-app-backend

# Frontend (default PORT 8081)
docker run --rm -e PORT=8081 -p 8081:8081 rust-workspace-frontend /workspace/bin/dioxus-app-frontend
```

**Note:** The backend expects a `public/` directory (for Dioxus static assets). The repo includes `public/.gitkeep`. The `project.toml` defines an inline buildpack that copies `public/` into the output layer — canonical, no buildpack magic.
