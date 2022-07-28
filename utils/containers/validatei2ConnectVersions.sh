#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source "/opt/utils/commonFunctions.sh"

function printUsage() {
  echo "Usage:"
  echo "    validatei2ConnectVersions.sh" 1>&2
  echo "    validatei2ConnectVersions.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:"
  echo "    -h Display the help." 1>&2
  echo "Required Environment Variables:" 1>&2
  echo "    CONFIG_I2CONNECT_SERVER_VERSION" 1>&2
  echo "    DECLARED_I2CONNECT_SERVER_VERSION" 1>&2
  echo "    CONFIG_CONNECTOR_VERSION" 1>&2
  echo "    DECLARED_CONNECTOR_VERSION" 1>&2
  exit 1
}

function validateEnvVarsAreSet() {
  checkVariableIsSet "${CONFIG_I2CONNECT_SERVER_VERSION}" "The expected i2 Connect Server version could NOT be determined from i2connect-server-version.json"
  checkVariableIsSet "${DECLARED_I2CONNECT_SERVER_VERSION}" "The declared i2 Connect Server version could NOT be determined from package.json"
  checkVariableIsSet "${CONFIG_CONNECTOR_VERSION}" "The expected connector version could NOT be determined from connector-version.json"
  checkVariableIsSet "${DECLARED_CONNECTOR_VERSION}" "The declared connector version could NOT be determined from package.json"
}

#######################################
# Gets the latest compatible version
# of the i2Connect Server npm package
# compatible with the given semantic
# version.
# Arguments:
#   The desired semantic version
#######################################
function geti2ConnectServerVersion() {
  local semantic_version="${1}"
  local npm_output
  local version

  npm_output=$(npm view "@i2analyze/i2connect@${semantic_version}" version | tail -n1)
  if [[ -z "${npm_output}" ]]; then
    printErrorAndExit "An i2 Connect Server version compatible with ${semantic_version} does NOT exist"
  fi

  if [[ $npm_output = *" "* ]]; then
    version="${npm_output##* }"
    version="${version//\'/}"
  else
    version="${npm_output}"
  fi
  echo "${version}"
}

function validateNodeSDKVersion() {
  local latest_config_i2connect_server_version
  local latest_declared_i2connect_server_version

  print "Validating i2 Connect Server version"
  echo "Expected i2 Connect Server version: ${CONFIG_I2CONNECT_SERVER_VERSION}"
  echo "Declared i2 Connect Server version: ${DECLARED_I2CONNECT_SERVER_VERSION}"
  latest_config_i2connect_server_version="$(geti2ConnectServerVersion "${CONFIG_I2CONNECT_SERVER_VERSION}")"
  latest_declared_i2connect_server_version="$(geti2ConnectServerVersion "${DECLARED_I2CONNECT_SERVER_VERSION}")"

  if [[ "${latest_config_i2connect_server_version}" != "${latest_declared_i2connect_server_version}" ]]; then
    waitForUserReply "The expected and declared i2 Connect Server versions (from i2connect-server-version.json and package.json) are not the compatible. Would you like to continue?"
  fi
}

function validateConnectorVersion() {
  print "Validating connector version"
  echo "Expected connector version: ${CONFIG_CONNECTOR_VERSION}"
  echo "Declared connector version: ${DECLARED_CONNECTOR_VERSION}"
  if [[ "${DECLARED_CONNECTOR_VERSION}" != "${CONFIG_CONNECTOR_VERSION}"* ]]; then
    waitForUserReply "The expected and declared connector versions (from connector-version.json and package.json) are not the compatible. Would you like to continue?"
  fi
}

while getopts ":h" flag; do
  case "${flag}" in
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

print "Validating versions for the connector: ${CONNECTOR_NAME}"
validateEnvVarsAreSet
validateNodeSDKVersion
validateConnectorVersion
