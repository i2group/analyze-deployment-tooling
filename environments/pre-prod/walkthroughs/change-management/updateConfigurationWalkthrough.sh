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

# Set the root directory
ROOT_DIR=$(pwd)/../../../..

# Load common variables and functions
source ../../utils/commonVariables.sh
source ../../utils/commonFunctions.sh
source ../../utils/serverFunctions.sh
source ../../utils/clientFunctions.sh

###############################################################################
# Removing Liberty containers                                                 #
###############################################################################
print "Removing Liberty container"
docker stop ${LIBERTY1_CONTAINER_NAME} ${LIBERTY2_CONTAINER_NAME}
docker rm ${LIBERTY1_CONTAINER_NAME} ${LIBERTY2_CONTAINER_NAME}

###############################################################################
# Updating the configuration                                                  #
###############################################################################
print "Updating configuration with the geospatial-configuration.json file from ${LOCAL_CONFIG_CHANGES_DIR}"
cp "${LOCAL_CONFIG_CHANGES_DIR}/geospatial-configuration.json" "${LOCAL_CONFIG_LIVE_DIR}"
buildLibertyConfiguredImage

###############################################################################
# Running the Liberty containers                                              #
###############################################################################
print "Running the newly configured Liberty"
runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"
waitFori2AnalyzeServiceToBeLive
