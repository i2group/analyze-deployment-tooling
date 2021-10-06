#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2021, IBM Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

function printUsage() {
  echo "Usage:"
  echo "  buildi2ConnectServerBaseImage.sh" 1>&2
  echo "  buildi2ConnectServerBaseImage.sh -a -l <dependency_label>" 1>&2
  echo "  buildi2ConnectServerBaseImage.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -a                    Produce or use artefacts on AWS." 1>&2
  echo "  -l <dependency_label> Name of dependency image label to use on AWS." 1>&2
  echo "  -h                    Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"
while getopts ":ahl:" flag; do
  case "${flag}" in
  a)
    AWS_ARTEFACTS="true"
    ;;
  l)
    I2A_DEPENDENCIES_IMAGES_TAG="${OPTARG}"
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

if [[ -z "${ENVIRONMENT}" ]]; then
  ENVIRONMENT="config-dev"
fi

if [[ "${AWS_ARTEFACTS}" && ( -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ) ]]; then
  usage
fi

if [[ -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
  I2A_DEPENDENCIES_IMAGES_TAG="latest"
fi

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

I2CONNECT_CONNECTOR_IMAGES_DIR="${IMAGES_DIR}/i2connect_server_base"

function buildImage() {
  local i2connect_version_file_path="${CONNECTOR_IMAGES_DIR}/i2connect-server-version.json"
  local latest_i2connect_version_file_path="${CONNECTOR_IMAGES_DIR}/.connector-images/i2connect-server-version.json"
  local version

  version=$(jq -r '.version' <"${i2connect_version_file_path}")

  # Track the latest version file to allow check for changes
  cp "${i2connect_version_file_path}" "${latest_i2connect_version_file_path}"

  echo "Version: ${version}"
  docker build --no-cache -t "${I2CONNECT_SERVER_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" --build-arg I2CONNECT_SERVER_VERSION="${version}" "${I2CONNECT_CONNECTOR_IMAGES_DIR}"
}

###############################################################################
# Building i2Connect connector image                                          #
###############################################################################
print "Building i2Connect Server base image"
buildImage
echo "Done"