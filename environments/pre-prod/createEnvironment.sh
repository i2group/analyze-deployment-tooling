#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Loading common variables and functions
source ./utils/commonVariables.sh
source ./utils/commonFunctions.sh

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
DEPLOYMENT_PATTERN="information-store-daod-opal"

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
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/example_connector"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/etl_client"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/i2a_tools"
  cp -p "${TOOLKIT_SCRIPTS_DIR}/utils/environment.sh" "${IMAGES_DIR}/ha_proxy"
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
  print "Creating ${LOCAL_DATABASE_SCRIPTS_DIR} folder"
  deleteFolderIfExists "${LOCAL_DATABASE_SCRIPTS_DIR}"
  mkdir -p "${LOCAL_DATABASE_SCRIPTS_DIR}"

  print "Creating ${LOCAL_DATABASE_SCRIPTS_DIR} folder"
  deleteFolderIfExists "${LOCAL_GENERATED_DIR}"
  mkdir -p "${LOCAL_GENERATED_DIR}"
}

function createLibertyStaticApplication() {
  print "Creating Liberty static application"
  deleteFolderIfExists "${LIBERTY_CONFIG_APP}"
  mkdir -p "${LIBERTY_CONFIG_APP}"

  "./utils/createLibertyStaticApplication.sh" "${LIBERTY_CONFIG_APP}" "${DEPLOYMENT_PATTERN}"
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers/." "${LIBERTY_CONFIG_APP}/third-party-dependencies/resources/jdbc/"
}

function createExampleConnectorApplication() {
  print "Building example connector image"
  deleteFolderIfExists "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"
  mkdir -p "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"

  cp -pr "${TOOLKIT_EXAMPLE_CONNECTOR_DIR}/"* "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"
}

###############################################################################
# Setting up i2 Analyze toolkit                                               #
###############################################################################
extractToolkit

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

print "Environment has been successfully prepared"
set +e
