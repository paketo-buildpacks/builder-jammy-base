#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDERDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly OPTIONS_JSON="${BUILDERDIR}/scripts/options.json"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  local name token
  local registryPort registryPid localRegistry setupLocalRegistry pushBuilderToLocalRegistry
  token=""
  registryPid=""
  setupLocalRegistry=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --name|-n)
        name="${2}"
        shift 2
        ;;

      --token|-t)
        token="${2}"
        shift 2
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  if [[ ! -d "${BUILDERDIR}/smoke" ]]; then
      util::print::warn "** WARNING  No Smoke tests **"
  fi

  if [[ -z "${name:-}" ]]; then
    name="testbuilder"
  fi

  tools::install "${token}"

  if [[ -f $OPTIONS_JSON ]]; then
    setupLocalRegistry="$(jq -r '.setup_local_registry //false' $OPTIONS_JSON)"
  fi

  if [[ "${setupLocalRegistry}" == "true" ]]; then
    registryPort=$(get::random::port)
    registryPid=$(local::registry::start $registryPort)
    localRegistry="127.0.0.1:$registryPort"
    export REGISTRY_URL="${localRegistry}"
  fi

  if [ -f $OPTIONS_JSON ]; then
    pushBuilderToLocalRegistry="$(jq -r '.push_builder_to_local_registry //false' $OPTIONS_JSON)"
  else
    pushBuilderToLocalRegistry="false"
  fi

  builder::create "${name}"
  image::pull::lifecycle "${name}"

  if [ "${pushBuilderToLocalRegistry}" == "true" ]; then
    docker tag "$name" "$REGISTRY_URL/$name"
    docker push "$REGISTRY_URL/$name"
    imageName="$REGISTRY_URL/$name"
  else
    imageName="$name"
  fi

  tests::run $imageName

  if [[ "${setupLocalRegistry}" == "true" ]]; then
    kill $registryPid
  fi
}

function usage() {
  cat <<-USAGE
smoke.sh [OPTIONS]

Runs the smoke test suite.

OPTIONS
  --help        -h         prints the command usage
  --name <name> -n <name>  sets the name of the builder that is built for testing
  --token <token>          Token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
USAGE
}

function tools::install() {
  local token
  token="${1}"

  util::tools::crane::install \
    --directory "${BUILDERDIR}/.bin" \
    --token "${token}"

  util::tools::pack::install \
    --directory "${BUILDERDIR}/.bin" \
    --token "${token}"
}

function builder::create() {
  local name
  name="${1}"

  util::print::title "Creating builder..."
  pack builder create "${name}" --config "${BUILDERDIR}/builder.toml"
}

function image::pull::lifecycle() {
  local name lifecycle_image
  name="${1}"

  lifecycle_image="index.docker.io/buildpacksio/lifecycle:$(
    pack builder inspect "${name}" --output json \
      | jq -r '.local_info.lifecycle.version'
  )"

  util::print::title "Pulling lifecycle image..."
  docker pull "${lifecycle_image}"
}

function tests::run() {
  local name
  name="${1}"

  util::print::title "Run Builder Smoke Tests"

  export CGO_ENABLED=0
  testout=$(mktemp)
  pushd "${BUILDERDIR}" > /dev/null
    if GOMAXPROCS="${GOMAXPROCS:-4}" go test -count=1 -timeout 0 ./smoke/... -v -run Smoke --name "${name}" | tee "${testout}"; then
      util::tools::tests::checkfocus "${testout}"
      util::print::success "** GO Test Succeeded **"
    else
      util::print::error "** GO Test Failed **"
    fi
  popd > /dev/null
}

main "${@:-}"
