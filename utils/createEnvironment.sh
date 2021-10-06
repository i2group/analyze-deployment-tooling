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

function usage() {
  echo "usage createEnvironment.sh -e {pre-prod|config-dev}" 1>&2
  exit 1
}

AWS_DEPLOY="false"
while getopts ":e:" flag; do
  case "${flag}" in
  e)
    ENVIRONMENT="${OPTARG}"
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
source "${ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
checkEnvironmentIsValid
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

###############################################################################
# Variables                                                                   #
###############################################################################

LIBERTY_CONFIG_APP="${IMAGES_DIR}/liberty_ubi_base/application"
SOLR_IMAGES_DIR="${IMAGES_DIR}/solr_redhat"
ETL_CLIENT_LIB_DIR="${LOCAL_ETL_TOOLKIT_DIR}/lib"
TOOLKIT_APPLICATION_DIR="${LOCAL_TOOLKIT_DIR}/application"
ETL_TOOLKIT_DIR="${LOCAL_TOOLKIT_DIR}/examples/etl/toolkit"
TOOLKIT_SCRIPTS_DIR="${LOCAL_TOOLKIT_DIR}/i2-tools/scripts"
TOOLKIT_EXAMPLE_CONNECTOR_DIR="${LOCAL_TOOLKIT_DIR}/examples/connectors/example-connector"

###############################################################################
# Function definitions                                                        #
###############################################################################

function extractToolkit() {
  print "Setting up i2Analyze Toolkit"

  deleteFolderIfExists "${LOCAL_I2ANALYZE_DIR}"
  mkdir -p "${LOCAL_I2ANALYZE_DIR}"

  tar -zxf "${PRE_REQS_DIR}/i2analyzeMinimal.tar.gz" -C "${LOCAL_I2ANALYZE_DIR}"
}

function populateImagesFoldersWithEnvironmentTool() {
  print "Adding environment variable resolution support"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/zookeeper_redhat"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/solr_redhat/scripts"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/liberty_ubi_base"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/sql_client/db-scripts"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/sql_server"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/db2_client/db-scripts"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/db2_server"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/example_connector"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/etl_client"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/i2a_tools"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/ha_proxy"
  
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${TEMPLATES_DIR}/node-connector-image"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${TEMPLATES_DIR}/springboot-connector-image"
}

function createSolrImageResources() {
  print "Creating Solr configuration folders"

  deleteFolderIfExists "${SOLR_IMAGES_DIR}/jars"
  mkdir -p "${SOLR_IMAGES_DIR}/jars/solr-data"

  cp -pr "${TOOLKIT_APPLICATION_DIR}/dependencies/solr-core-extension/." "${SOLR_IMAGES_DIR}/jars/"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/dependencies/solr-jetty-wrapper/." "${SOLR_IMAGES_DIR}/jars/"
  cp -pr "${LOCAL_TOOLKIT_DIR}/application/dependencies/solr-extension/." "${SOLR_IMAGES_DIR}/jars/solr-data/"
}

function createEtlToolkitImageResources() {
  print "Setting up ETL Toolkit"

  deleteFolderIfExists "${LOCAL_ETL_TOOLKIT_DIR}"
  mkdir -p "${LOCAL_ETL_TOOLKIT_DIR}"
  mkdir -p "${ETL_CLIENT_LIB_DIR}"

  cp -pr "${ETL_TOOLKIT_DIR}/." "${LOCAL_ETL_TOOLKIT_DIR}"
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers/." "${ETL_CLIENT_LIB_DIR}"
  cp -pr "${LOCAL_TOOLKIT_DIR}/i2-tools/jars/." "${ETL_CLIENT_LIB_DIR}"
}

function populateImageFolderWithToolsResources() {
  local IMAGE_FOLDER=${1}
  print "Setting up ${IMAGE_FOLDER} image"

  deleteFolderIfExists "${IMAGES_DIR}/${IMAGE_FOLDER}/tools"
  mkdir -p "${IMAGES_DIR}/${IMAGE_FOLDER}/tools"

  cp -pr "${LOCAL_TOOLKIT_DIR}/i2-tools" "${IMAGES_DIR}/${IMAGE_FOLDER}/tools"
  cp -pr "${LOCAL_TOOLKIT_DIR}/scripts" "${IMAGES_DIR}/${IMAGE_FOLDER}/tools"
}

function createDatabaseScriptsAndGeneratedFolder() {
  print "Creating ${LOCAL_DATABASE_SCRIPTS_DIR}/generated folder"
  deleteFolderIfExists "${LOCAL_DATABASE_SCRIPTS_DIR}"
  mkdir -p "${LOCAL_DATABASE_SCRIPTS_DIR}/generated/dynamic"
}

function createLibertyStaticApplication() {
  print "Creating Liberty static application"
  deleteFolderIfExists "${LIBERTY_CONFIG_APP}"
  mkdir -p "${LIBERTY_CONFIG_APP}"

  "${ROOT_DIR}/utils/createLibertyStaticApplication.sh" "${ENVIRONMENT}" "${LIBERTY_CONFIG_APP}"

  # Copy jdbc-drivers and verify they exist in the liberty image folder
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers/." "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc/"
  if [ "$(ls -A "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc/mssql-jdbc-7."*".jre11.jar")" ]; then
    printInfo "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc has the mssql jdbc drivers"
  else
    printErrorAndExit "${PRE_REQS_DIR}/jdbc-drivers does NOT have the correct mssql jdbc drivers, expecting: mssql-jdbc-7.*.jre11.jar"
  fi
}

function createExampleConnectorApplication() {
  print "Building example connector image"
  deleteFolderIfExists "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"
  mkdir -p "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"

  cp -pr "${TOOLKIT_EXAMPLE_CONNECTOR_DIR}/"* "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"
}

function populateConnectorImagesFolder() {
  local i2connect_server_version_file="${CONNECTOR_IMAGES_DIR}/i2connect-server-version.json"
  print "Populate connector-images folder with defaults"
  mkdir -p "${CONNECTOR_IMAGES_DIR}/.connector-images"

  if [[ ! -f "${i2connect_server_version_file}" ]]; then
    jq -n "{\"version\": \"latest\"}" > "${i2connect_server_version_file}"
  fi
}

###############################################################################
# Setting up i2 Analyze toolkit                                               #
###############################################################################
extractToolkit

# Add new scripts for db2 until new toolkit is released
cp -pr "${ROOT_DIR}/utils/templates/i2-tools/scripts/." "${TOOLKIT_SCRIPTS_DIR}"

###############################################################################
# Adding environment variable resolution support                              #
###############################################################################
populateImagesFoldersWithEnvironmentTool

###############################################################################
# Creating Solr configuration folders                                         #
###############################################################################
createSolrImageResources

###############################################################################
# Setting up ETL Toolkit                                                      #
###############################################################################
createEtlToolkitImageResources

###############################################################################
# Setting up i2 tools image                                                   #
###############################################################################
populateImageFolderWithToolsResources "i2a_tools"
populateImageFolderWithToolsResources "sql_client"
populateImageFolderWithToolsResources "db2_client"

###############################################################################
# Creating Example connector application                                      #
###############################################################################
createExampleConnectorApplication

###############################################################################
# Creating Database scripts folder                                            #
###############################################################################
createDatabaseScriptsAndGeneratedFolder

###############################################################################
# Creating Liberty static application                                         #
###############################################################################
createLibertyStaticApplication

###############################################################################
# Populate Connector Images folder with defaults                              #
###############################################################################
populateConnectorImagesFolder

print "Environment has been successfully prepared"
