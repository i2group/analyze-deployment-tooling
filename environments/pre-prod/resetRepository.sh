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
cd "${SCRIPT_DIR}"

# Load common variables and functions
source ./utils/commonVariables.sh
source ./utils/commonFunctions.sh

###############################################################################
# Functions                                                                   #
###############################################################################

function removeAllImages() {
  print "Removing i2Analyze Docker images"
  docker image rm \
    "${SQL_SERVER_IMAGE_NAME}" \
    "${SQL_CLIENT_IMAGE_NAME}" \
    "${ETL_CLIENT_IMAGE_NAME}" \
    "${SOLR_IMAGE_NAME}" \
    "${ZOOKEEPER_IMAGE_NAME}" \
    "${LIBERTY_BASE_IMAGE_NAME}" \
    "${LIBERTY_CONFIGURED_IMAGE_NAME}" \
    "${I2A_TOOLS_IMAGE_NAME}" \
    "${LOAD_BALANCER_IMAGE_NAME}" ||
    true
}

function cleanDockerImagesDirectories() {
  print "Cleaning images directories"
  # Remove copied environment.sh files
  environmentFiles=$(find "$IMAGES_DIR" -type f -name "environment.sh")
  for file in $environmentFiles
  do
    rm -f "$file"
  done
  # remove copied server.extensions.xml file
  rm -f "${IMAGES_DIR}/liberty_ubi_combined/server.extensions.xml"
}

###############################################################################
# Remove Docker resources                                                     #
###############################################################################
removeAllContainersAndNetwork
removeDockerVolumes
removeAllImages
cleanDockerImagesDirectories

###############################################################################
# Remove i2 Analyze configuration                                             #
###############################################################################
print "Removing i2Analyze configuration"
deleteFolderIfExists "${LOCAL_GENERATED_DIR}"
deleteFolderIfExists "${LOCAL_I2ANALYZE_DIR}"

###############################################################################
# Removing old ssh keys                                                       #
###############################################################################
print "Removing ssh keys"
deleteFolderIfExists "${LOCAL_KEYS_DIR}"

###############################################################################
# Remove generatedSecrets                                                     #
###############################################################################
print "Remove Generated secrets"
deleteFolderIfExists "${GENERATED_SECRETS_DIR}"

###############################################################################
# Remove image resources                                                      #
###############################################################################
print "Removing i2Analyze image resources"
deleteFolderIfExists "${IMAGES_DIR}/liberty_ubi_base/application"
deleteFolderIfExists "${IMAGES_DIR}/liberty_ubi_combined/classes"
deleteFolderIfExists "${IMAGES_DIR}/solr_redhat/jars"
deleteFolderIfExists "${LOCAL_ETL_TOOLKIT_DIR}"

###############################################################################
# Remove database scripts                                                     #
###############################################################################
print "Removing old database scripts"
deleteFolderIfExists "${LOCAL_GENERATED_DIR}"
deleteFolderIfExists "${LOCAL_DATABASE_SCRIPTS_DIR}"

###############################################################################
# Remove saved cookies                                                        #
###############################################################################
print "Removing saved cookies"
deleteFolderIfExists "${COOKIE_PATH}"

###############################################################################
# Remove ETL toolkit                                                          #
###############################################################################
print "Removing ETL toolkit"
deleteFolderIfExists "${LOCAL_ETL_TOOLKIT_DIR}"

###############################################################################
# Remove example connector application                                        #
###############################################################################
print "Removing Example connector"
deleteFolderIfExists "${LOCAL_EXAMPLE_CONNECTOR_APP_DIR}"

set +e
