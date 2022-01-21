#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
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
  echo "    buildImages.sh" 1>&2
  echo "    buildImages.sh -a -l dependency_label" 1>&2
  echo "    buildImages.sh -e {pre-prod}" 1>&2
  echo "    buildImages.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:"
  echo "    -a Produce or use artefacts on AWS." 1>&2
  echo "    -l Name of dependency image label to use on AWS." 1>&2
  echo "    -e {pre-prod} Used to generate images for pre-prod example." 1>&2
  echo "    -h Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"
while getopts ":e:l:ah" flag; do
  case "${flag}" in
  e)
    ENVIRONMENT="${OPTARG}"
    ;;
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

if [[ "${AWS_ARTEFACTS}" && -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
  usage
fi

if [[ -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
  I2A_DEPENDENCIES_IMAGES_TAG="latest"
fi

if [[ -z "${ENVIRONMENT}" ]]; then
  ENVIRONMENT="config-dev"
fi

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

###############################################################################
# Building load balancer image                                                #
###############################################################################
print "Building load balancer image"
docker build -t "${LOAD_BALANCER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/ha_proxy"

###############################################################################
# Building Liberty base image                                                 #
###############################################################################
print "Building Liberty base image"
docker build -t "${LIBERTY_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/liberty_ubi_base"

###############################################################################
# Building Solr image                                                         #
###############################################################################
print "Building Solr image"
docker build -t "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/solr_redhat"

###############################################################################
# Building ZooKeeper image                                                    #
###############################################################################
print "Building ZooKeeper image"
docker build -t "${ZOOKEEPER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/zookeeper_redhat"

###############################################################################
# Building Db2 Server image                                                   #
###############################################################################
print "Building Db2 Server image"
docker build -t "${DB2_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/db2_server"

###############################################################################
# Building Db2 Client image                                                   #
###############################################################################
print "Building Db2 Client image"
docker build -t "${DB2_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/db2_client"

###############################################################################
# Building SQL Server image                                                   #
###############################################################################
print "Building SQL Server image"
docker build -t "${SQL_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/sql_server"

###############################################################################
# Building SQL Client image                                                   #
###############################################################################
print "Building SQL Client image"
docker build -t "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/sql_client"

###############################################################################
# Building i2 Analyze Tool image                                              #
###############################################################################
print "Building i2 Analyze Tool image"
docker image build -t "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/i2a_tools" \
  --build-arg USER_UID="$(id -u "${USER}")"

###############################################################################
# Building ETL Client image                                                   #
###############################################################################
print "Building ETL Client image"
if [[ -d "${IMAGES_DIR}/etl_client/etltoolkit/classes" ]]; then
  echo "Clearing down etltoolkit classes folder"
  rm -rf "${IMAGES_DIR}/etl_client/etltoolkit/classes"
fi
echo "Populating etltoolkit classes folder"
mkdir "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_CONFIG_I2_TOOLS_DIR}/"* "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_ISTORE_NAMES_SQL_SERVER_PROPERTIES_FILE}" "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_ISTORE_NAMES_DB2_PROPERTIES_FILE}" "${IMAGES_DIR}/etl_client/etltoolkit/classes"
docker build -t "${ETL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/etl_client" \
  --build-arg USER_UID="$(id -u "${USER}")" \
  --build-arg BASE_IMAGE="${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"

###############################################################################
# Building Example connector image                                            #
###############################################################################
docker build -t "${CONNECTOR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/example_connector"

###############################################################################
# Building i2Connect Server base image                                        #
###############################################################################
if [[ "${AWS_ARTEFACTS}" == "true" ]]; then
  print "Running buildi2ConnectServerBaseImage.sh"
  "${ROOT_DIR}/utils/buildi2ConnectServerBaseImage.sh" -a -l "${I2A_DEPENDENCIES_IMAGES_TAG}"
else
  print "Running buildi2ConnectServerBaseImage.sh"
  "${ROOT_DIR}/utils/buildi2ConnectServerBaseImage.sh"
fi
