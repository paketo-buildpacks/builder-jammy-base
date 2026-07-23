#!/usr/bin/env bash
# Build a test builder image using local octopilot/rust and octopilot/helm buildpacks
# (so we don't require them to be published to GHCR). Then you can use the test
# builder with: pack build <image> --builder <test-builder-ref> --path <app-dir>
set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDER_ROOT="$(cd "${PROGDIR}/.." && pwd)"
readonly BUILDPS_ROOT="$(cd "${BUILDER_ROOT}/.." && pwd)"
readonly LOCAL_BP_DIR="${BUILDER_ROOT}/.local-buildpacks"
readonly TEST_BUILDER_IMAGE="${TEST_BUILDER_IMAGE:-ghcr.io/octopilot/builder-jammy-base:test}"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"
# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  util::print::title "Building test builder with local Rust and Helm buildpacks"
  mkdir -p "${LOCAL_BP_DIR}"

  # Package Rust buildpack
  if [[ -f "${BUILDPS_ROOT}/rust/scripts/package.sh" ]]; then
    util::print::title "Packaging Rust buildpack"
    local rust_version
    rust_version=$(awk -F'"' '/^  version = / {print $2; exit}' "${BUILDPS_ROOT}/rust/buildpack.toml")
    (cd "${BUILDPS_ROOT}/rust" && ./scripts/package.sh --version "${rust_version}")
    cp "${BUILDPS_ROOT}/rust/build/buildpack.tgz" "${LOCAL_BP_DIR}/rust.tgz"
  else
    util::print::error "Rust buildpack not found at ${BUILDPS_ROOT}/rust (run from buildpacks repo)"
  fi

  # Package Helm buildpack
  if [[ -f "${BUILDPS_ROOT}/helm/scripts/package.sh" ]]; then
    util::print::title "Packaging Helm buildpack"
    local helm_version
    helm_version=$(awk -F'"' '/^  version = / {print $2; exit}' "${BUILDPS_ROOT}/helm/buildpack.toml")
    (cd "${BUILDPS_ROOT}/helm" && ./scripts/package.sh --version "${helm_version}")
    cp "${BUILDPS_ROOT}/helm/build/buildpack.tgz" "${LOCAL_BP_DIR}/helm.tgz"
  else
    util::print::error "Helm buildpack not found at ${BUILDPS_ROOT}/helm (run from buildpacks repo)"
  fi

  # Generate builder-test.toml with file:// URIs for octopilot buildpacks
  util::print::title "Generating builder-test.toml"
  sed -e "s|uri = \"docker://ghcr.io/octopilot/rust:0.1.0\"|uri = \"file://${LOCAL_BP_DIR}/rust.tgz\"|" \
      -e "s|uri = \"docker://ghcr.io/octopilot/helm:0.1.0\"|uri = \"file://${LOCAL_BP_DIR}/helm.tgz\"|" \
      "${BUILDER_ROOT}/builder.toml" > "${BUILDER_ROOT}/builder-test.toml"

  # Install pack and create builder (no --publish)
  util::tools::pack::install --directory "${BUILDER_ROOT}/.bin" --token ""
  export PATH="${BUILDER_ROOT}/.bin:${PATH}"

  util::print::title "Creating test builder image: ${TEST_BUILDER_IMAGE}"
  pack builder create "${TEST_BUILDER_IMAGE}" \
    --config "${BUILDER_ROOT}/builder-test.toml"

  util::print::info "Test builder created: ${TEST_BUILDER_IMAGE}"
  util::print::info "Use it with: pack build <image> --builder ${TEST_BUILDER_IMAGE} --path <app-dir>"
}

main "${@:-}"
