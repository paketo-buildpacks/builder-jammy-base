#!/usr/bin/env bash
# Run pack build against cronjob-log-monitor (Rust app) and cronjob-log-monitor/chart (Helm)
# using the test builder. Requires build-test-builder.sh to have been run first.
set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDER_ROOT="$(cd "${PROGDIR}/.." && pwd)"
readonly TEST_BUILDER_IMAGE="${TEST_BUILDER_IMAGE:-ghcr.io/octopilot/builder-jammy-base:test}"
CRONJOB_MONITOR_ROOT="${CRONJOB_MONITOR_ROOT:-}"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  if [[ -z "${CRONJOB_MONITOR_ROOT:-}" ]]; then
    # Default: sibling of buildpacks repo (octopilot/cronjob-log-monitor)
    CRONJOB_MONITOR_ROOT="$(cd "${BUILDER_ROOT}/../.." && pwd)/cronjob-log-monitor"
  fi
  if [[ ! -d "${CRONJOB_MONITOR_ROOT}" ]]; then
    util::print::error "cronjob-log-monitor not found at ${CRONJOB_MONITOR_ROOT}. Set CRONJOB_MONITOR_ROOT."
  fi

  util::print::title "Testing builder ${TEST_BUILDER_IMAGE} against cronjob-log-monitor"
  util::print::info "Rust app path: ${CRONJOB_MONITOR_ROOT}"
  util::print::info "Helm chart path: ${CRONJOB_MONITOR_ROOT}/chart"

  export PATH="${BUILDER_ROOT}/.bin:${PATH}"
  if [[ ! -x "${BUILDER_ROOT}/.bin/pack" ]]; then
    util::print::error "pack not found. Run scripts/build-test-builder.sh first."
  fi

  # 1) Build Rust app (root has Cargo.toml)
  util::print::title "Pack build (Rust): cronjob-log-monitor"
  pack build cronjob-log-monitor:test-rust \
    --builder "${TEST_BUILDER_IMAGE}" \
    --path "${CRONJOB_MONITOR_ROOT}" \
    --pull-policy if-not-present

  util::print::info "Rust image built: cronjob-log-monitor:test-rust"

  # 2) Build Helm chart (chart/ has Chart.yaml)
  util::print::title "Pack build (Helm): cronjob-log-monitor/chart"
  pack build cronjob-log-monitor-chart:test-helm \
    --builder "${TEST_BUILDER_IMAGE}" \
    --path "${CRONJOB_MONITOR_ROOT}/chart" \
    --pull-policy if-not-present

  util::print::info "Helm chart image built: cronjob-log-monitor-chart:test-helm"
  util::print::title "Both builds succeeded."
}

main "${@:-}"
