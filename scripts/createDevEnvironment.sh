#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

echo "BASH_VERSION: $BASH_VERSION"
set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "This project should be run inside a VSCode Dev Container. For more information read, the Getting Started guide at https://i2group.github.io/analyze-containers/content/getting_started.html"
  exit 1
fi

function printUsage() {
  echo "Usage:"
  echo "  createDevEnvironment.sh [-v] [-y]"
  echo "  createDevEnvironment.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -v                                     Verbose output." 1>&2
  echo "  -y                                     Answer 'yes' to all prompts." 1>&2
  echo "  -h                                     Display the help." 1>&2
  exit 1
}

while getopts ":vyh" flag; do
  case "${flag}" in
  y)
    YES_FLAG="true"
    ;;
  v)
    VERBOSE="true"
    ;;
  h)
    help
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"

source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"
warnRootDirNotInPath
checkDockerIsRunning
createLicenseConfiguration

extra_args=()
if [[ "${VERBOSE}" == "true" ]]; then
  extra_args+=("-v")
fi

print "Running createEnvironment.sh script"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createEnvironment.sh" -e "${ENVIRONMENT}" "${extra_args[@]}"

print "Running createConfiguration.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createConfiguration.sh" -e "${ENVIRONMENT}" "${extra_args[@]}"

setDependenciesTagIfNecessary

print "Running buildImages.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildImages.sh" "${extra_args[@]}"

print "Running generateSecrets.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/generateSecrets.sh" "${extra_args[@]}"

echo "Success: Development environment created"
