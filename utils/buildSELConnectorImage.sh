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
  echo "  buildSELConnectorImage.sh -a -l <dependency_label>" 1>&2
  echo "  buildSELConnectorImage.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -a Produce or use artefacts on AWS." 1>&2
  echo "  -l <dependency_label> Name of dependency image label to use on AWS." 1>&2
  echo "  -h Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"
while getopts "ahl:" flag; do
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

###############################################################################
# Variables                                                                   #
###############################################################################

SEL_IMAGES_DIR="${IMAGES_DIR}/sel_connector"
LOCAL_SEL_DIR="${PRE_REQS_DIR}/sel-platform"
SEL_SERVER_DIR="${SEL_IMAGES_DIR}/server"

###############################################################################
# Function definitions                                                        #
###############################################################################

function extractSELPlatform() {
  print "Setting up SEL Connector Platform"

  deleteFolderIfExists "${LOCAL_SEL_DIR}"
  mkdir -p "${LOCAL_SEL_DIR}"

  unzip -d "${LOCAL_SEL_DIR}" "${PRE_REQS_DIR}/loopback-connector-server.zip"

  deleteFolderIfExists "${SEL_SERVER_DIR}"
  mkdir -p "${SEL_SERVER_DIR}"
  cp -R "${LOCAL_SEL_DIR}/loopback-connector-server/." "${SEL_SERVER_DIR}/"

  # Create the default.json file
  cat <"${ROOT_DIR}/utils/templates/sel-config.json" | jq '.sslSettings +=
  {
    "enabled": true,
    "port": 3700,
    "keyFile": "'"${CONTAINER_CERTS_DIR}/server.key"'",
    "certFile": "'"${CONTAINER_CERTS_DIR}/server.cer"'"
  }' >"${SEL_SERVER_DIR}/config/default.json"
}

###############################################################################
# Building SEL connector image                                                #
###############################################################################
#extractSELPlatform
docker build -t "${SEL_CONNECTOR_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/sel_connector"
