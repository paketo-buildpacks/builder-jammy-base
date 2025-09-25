#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOTDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly OPTIONS_JSON="${ROOTDIR}/scripts/options.json"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  local name token
  local registryPort registryPid localRegistryUrl pushBuilderToLocalRegistry
  local builderDir builderArray targetPlatform
  token=""
  registryPid=""
  builderDir=""
  builderArray=()
  targetPlatform=""
  localRegistryUrl=""
  pushBuilderToLocalRegistry=""

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

      --builder-dir)
        builderDir="${2}"
        shift 2
        ;;

      --target-platform)
        targetPlatform="${2}"
        shift 2
        ;;

      --local-registry-url)
        localRegistryUrl="${2}"
        shift 2
        ;;

      --push-builder-to-local-registry)
        pushBuilderToLocalRegistry="${2}"
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

  if [[ -z "${targetPlatform}" ]]; then
    os=$(util::tools::os macos)
    arch=$(util::tools::arch)
    targetPlatform="${os}/${arch}"
  fi

  if [ -n "${builderDir}" ]; then
    if [[ -z "${name:-}" ]]; then
      name="testbuilder"
      util::print::info "Using default name for the builder: ${name}"
    fi
    builderArray+=($(jq -n --arg name "$name" --arg path "$builderDir" '{name: $name, path: $path}' | jq -c '.'))
  elif [[ -f ${ROOTDIR}/builders.json ]]; then
    builderArray=($(jq -r -c '.builders[]' ${ROOTDIR}/builders.json))
  else
    if [[ -z "${name:-}" ]]; then
      name="testbuilder"
      util::print::info "Using default name for the builder: ${name}"
    fi
    util::print::info "Using current directory as the builder directory."
    builderArray+=($(jq -n --arg name "$name" --arg path "$ROOTDIR" '{name: $name, path: $path}' | jq -c '.'))
  fi

  util::print::info "Found the following builder directories:"
  for builder in "${builderArray[@]}"; do
    builderName=$(jq -r '.name' <<<"${builder}")
    builderPath=$(jq -r '.path' <<<"${builder}")
    util::print::info " - Name: ${builderName}, Path: ${builderPath}"
  done

  tools::install "${token}"

  if [ "${pushBuilderToLocalRegistry}" != "" ]; then
    if [[ "${pushBuilderToLocalRegistry}" != "true" && "${pushBuilderToLocalRegistry}" != "false" ]]; then
      util::print::error "--push-builder-to-local-registry must be 'true' or 'false'"
    fi
    util::print::info "Using command line argument for push_builder_to_local_registry: ${pushBuilderToLocalRegistry}"
  elif [ -f $OPTIONS_JSON ]; then
    pushBuilderToLocalRegistry="$(jq -r '.push_builder_to_local_registry //false' $OPTIONS_JSON)"
  else
    pushBuilderToLocalRegistry="false"
  fi

  trap 'cleanup "$registryPid" "$builderName"' EXIT

  # Set up local registry to push the builder(s)
  if [[ "${pushBuilderToLocalRegistry}" == "true" && "${localRegistryUrl}" == "" ]]; then
    registryPort=$(get::random::port)
    registryPid=$(local::registry::start $registryPort)
    localRegistryUrl="127.0.0.1:$registryPort"
    util::print::info "Started local registry at ${localRegistryUrl} with PID ${registryPid}"
  fi

  local testout
  testout=$(mktemp)
  for builderDir in "${builderArray[@]}"; do
    builderName=$(jq -r '.name' <<<"${builderDir}")
    builderDir=$(jq -r '.path' <<<"${builderDir}")

    util::print::info "Running tests for builder: ${builderName}"

    if [[ ! -d "${builderDir}" ]]; then
      util::print::error "Builder directory ${builderDir} does not exist."
    fi

    if [[ ! -d "${builderDir}/smoke" ]]; then
        util::print::warn "** WARNING  No Smoke tests **"
    fi

    builder::create "${builderName}" "${builderDir}" "${localRegistryUrl}" "${targetPlatform}"

    if [[ "${pushBuilderToLocalRegistry}" == "true" ]]; then
      builderName="$localRegistryUrl/$builderName"
    else
      builderName="$builderName"
    fi

    image::pull::lifecycle "${builderName}" "${pushBuilderToLocalRegistry}"

    tests::run "${builderName}" "${testout}"
  done

  util::tools::tests::checkfocus "${testout}"
  util::print::success "** GO Test Succeeded for all builders**"
}

function cleanup (){
  local registryPid builderName
  registryPid="${1}"
  builderName="${2}"

  if [[ "${registryPid}" != "" ]]; then
    kill "${registryPid}"
  fi
  if [[ "${builderName}" != "" ]]; then
    docker rmi "${builderName}" || true
  fi
}

function usage() {
  cat <<-USAGE
smoke.sh [OPTIONS]

Runs the smoke test suite.

OPTIONS
  --help        -h                  prints the command usage
  --name <name> -n <name>           sets the name of the builder that is built for testing
  --token <token>                   token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
  --builder-dir <dir>               sets the directory of the builder to test. Defaults to the current directory.
  --target-platform                 sets the target platform to build the builder image for. E.g. linux/amd64, linux/arm64, etc.
                                    Defaults host machine's OS/arch.
  --local-registry-url              sets the local registry URL to push the builder image to. E.g. 127.0.0.1:5000
  --push-builder-to-local-registry  if "true", pushes the builder image to a local registry.
                                    Defaults value false or the value in scripts/options.json if the file exists.
                                    Note: if true and --local-registry-url is not set, a local registry will be started on a random port.
USAGE
}

function tools::install() {
  local token
  token="${1}"

  util::tools::crane::install \
    --directory "${ROOTDIR}/.bin" \
    --token "${token}"

  util::tools::pack::install \
    --directory "${ROOTDIR}/.bin" \
    --token "${token}"
}

function builder::create() {
  local builderName path localRegistryUrl
  builderName="${1}"
  path="${2}"
  localRegistryUrl="${3:-}"
  targetPlatform="${4}"

  if [[ "${localRegistryUrl}" != "" ]]; then
    util::print::title "Creating ${localRegistryUrl}/${builderName} builder image..."
    pack builder create "${localRegistryUrl}/${builderName}" --config "${path}/builder.toml"  --target "${targetPlatform}" --publish
  else
    util::print::title "Creating ${builderName} builder image..."
    pack builder create "${builderName}" --config "${path}/builder.toml" --target "${targetPlatform}"
  fi
}

function image::pull::lifecycle() {
  local name lifecycle_image pushBuilderToLocalRegistry
  name="${1}"
  pushBuilderToLocalRegistry="${2:-false}"

  if [[ "${pushBuilderToLocalRegistry}" == "true" ]]; then
    lifecycle_image="index.docker.io/buildpacksio/lifecycle:$(
      pack builder inspect "${name}" --output json \
        | jq -r '.remote_info.lifecycle.version'
    )"
  else
    lifecycle_image="index.docker.io/buildpacksio/lifecycle:$(
      pack builder inspect "${name}" --output json \
        | jq -r '.local_info.lifecycle.version'
    )"
  fi

  util::print::title "Pulling lifecycle image..."
  docker pull "${lifecycle_image}"
}

function tests::run() {
  local name
  name="${1}"

  util::print::title "Run Builder Smoke Tests for ${name}..."

  export CGO_ENABLED=0
  pushd "${builderDir}" > /dev/null
    if GOMAXPROCS="${GOMAXPROCS:-4}" go test -count=1 -timeout 0 ./smoke/... -v -run Smoke --name "${name}" | tee "${testout}"; then
      util::print::info "** GO Test Succeeded with ${name} **"
    else
      util::print::error "** GO Test Failed with ${name} **"
    fi
  popd > /dev/null
}

main "${@:-}"
