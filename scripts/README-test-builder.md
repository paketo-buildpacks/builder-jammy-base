# Test builder (local Rust + Helm buildpacks)

Build a builder image that uses **local** octopilot/rust and octopilot/helm buildpacks (no need to publish them to GHCR), then verify it against cronjob-log-monitor.

**Requirements:** Docker running, and the `buildpacks` repo layout:

- `buildpacks/builder-jammy-base/` (this repo)
- `buildpacks/rust/`
- `buildpacks/helm/`

## 1. Build the test builder

From `builder-jammy-base`:

```bash
./scripts/build-test-builder.sh
```

This will:

- Package the Rust buildpack from `../rust` → `.local-buildpacks/rust.tgz`
- Package the Helm buildpack from `../helm` → `.local-buildpacks/helm.tgz`
- Generate `builder-test.toml` (file:// URIs for those two buildpacks)
- Run `pack builder create ghcr.io/octopilot/builder-jammy-base:test --config builder-test.toml`

Override the image tag:

```bash
TEST_BUILDER_IMAGE=my-registry/my-builder:test ./scripts/build-test-builder.sh
```

## 2. Test against cronjob-log-monitor

With the test builder built and **cronjob-log-monitor** at a path sibling to `buildpacks` (e.g. `octopilot/cronjob-log-monitor`):

```bash
./scripts/test-cronjob-log-monitor.sh
```

This runs:

1. **Pack build (Rust):** `pack build cronjob-log-monitor:test-rust --path <cronjob-log-monitor>`
2. **Pack build (Helm):** `pack build cronjob-log-monitor-chart:test-helm --path <cronjob-log-monitor>/chart`

If cronjob-log-monitor is elsewhere:

```bash
CRONJOB_MONITOR_ROOT=/path/to/cronjob-log-monitor ./scripts/test-cronjob-log-monitor.sh
```

Both images are built locally (no push). You can run them to confirm the Rust binary and the Helm chart artifact.
