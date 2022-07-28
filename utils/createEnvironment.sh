#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

function usage() {
  echo "usage createEnvironment.sh -e {pre-prod|config-dev} [-v]" 1>&2
  exit 1
}

while getopts ":e:v" flag; do
  case "${flag}" in
  e)
    ENVIRONMENT="${OPTARG}"
    ;;
  v)
    VERBOSE="true"
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
checkEnvironmentIsValid
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

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
FIXPACK_DIR="${PRE_REQS_DIR}/fixpack"

###############################################################################
# Function definitions                                                        #
###############################################################################

function extractToolkit() {
  local toolkit_minimal_version
  print "Setting up i2 Analyze Minimal Toolkit"

  deleteFolderIfExists "${LOCAL_I2ANALYZE_DIR}"
  mkdir -p "${LOCAL_I2ANALYZE_DIR}"

  tar -zxf "${PRE_REQS_DIR}/i2analyzeMinimal.tar.gz" -C "${LOCAL_I2ANALYZE_DIR}"
  toolkit_minimal_version=$(cat "${LOCAL_I2ANALYZE_DIR}/toolkit/scripts/version.txt")
  if [[ "${toolkit_minimal_version%.*}" != "${SUPPORTED_I2ANALYZE_VERSION}" ]]; then
    printErrorAndExit "i2 Analyze Minimal Toolkit version ${toolkit_minimal_version%%-*} is not compatible with analyze-containers version ${VERSION}"
  fi
}

function extractFixPackIfNecessary() {
  local fixpack_version

  if [[ -f "${PRE_REQS_DIR}/i2analyzeFixPack.tar.gz" ]]; then
    deleteFolderIfExistsAndCreate "${FIXPACK_DIR}"
    tar -zxf "${PRE_REQS_DIR}/i2analyzeFixPack.tar.gz" -C "${FIXPACK_DIR}"
    fixpack_version=$(cat "${FIXPACK_DIR}"/toolkit/version/*.txt)
    if [[ "${fixpack_version%.*}" != "${SUPPORTED_I2ANALYZE_VERSION}" ]]; then
      printErrorAndExit "Fix Pack version ${fixpack_version} is not compatible with i2 Analyze Toolkit Minimal version ${SUPPORTED_I2ANALYZE_VERSION}"
    fi
    print "Applying i2 Analyze Fix Pack ${fixpack_version}"
    cp -r "${FIXPACK_DIR}/toolkit/application/shared/." "${TOOLKIT_APPLICATION_DIR}/shared"
    cp -r "${FIXPACK_DIR}/toolkit/application/targets/opal-services-is-daod/." "${TOOLKIT_APPLICATION_DIR}/targets/opal-services"
    find "${FIXPACK_DIR}/toolkit/version/" -type f -name "*.txt" -print0 | xargs -I{} -0 cp {} "${LOCAL_TOOLKIT_DIR}/scripts/version.txt"
  fi
  deleteFolderIfExists "${FIXPACK_DIR}"
}

function populateImagesFoldersWithEnvironmentTool() {
  print "Adding environment variable resolution support"
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

  "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createLibertyStaticApplication.sh" "${ENVIRONMENT}" "${LIBERTY_CONFIG_APP}"

  # Copy jdbc-drivers and verify they exist in the liberty image folder
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers/." "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc/"
  if [ "$(ls -A "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc/mssql-jdbc-9."*".jre11.jar")" ]; then
    printInfo "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc has the mssql jdbc drivers"
  else
    printErrorAndExit "${PRE_REQS_DIR}/jdbc-drivers does NOT have the correct mssql jdbc drivers, expecting: mssql-jdbc-9.*.jre11.jar"
  fi
}

function createExampleConnectorApplication() {
  print "Building example connector image"
  deleteFolderIfExistsAndCreate "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"

  cp -pr "${TOOLKIT_EXAMPLE_CONNECTOR_DIR}/"* "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"
}

function populateConnectorImagesFolder() {
  local i2connect_server_version_file="${CONNECTOR_IMAGES_DIR}/i2connect-server-version.json"
  print "Populate connector-images folder with defaults"
  createFolder "${PREVIOUS_CONNECTOR_IMAGES_DIR}"

  if [[ ! -f "${i2connect_server_version_file}" ]]; then
    jq -n "{\"version\": \"latest\"}" >"${i2connect_server_version_file}"
  fi
}

###############################################################################
# Setting up i2 Analyze toolkit                                               #
###############################################################################
extractToolkit
extractFixPackIfNecessary

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
