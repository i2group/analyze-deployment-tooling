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
print "Removing Liberty containers"
docker stop "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"
docker rm "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"

###############################################################################
# Modifying the schema                                                        #
###############################################################################
print "Making changes to the i2 Analyze Schema"
cp "${LOCAL_CONFIG_CHANGES_DIR}/schema.xml" "${LOCAL_CONFIG_COMMON_DIR}"
buildLibertyConfiguredImage

###############################################################################
# Validating the schema                                                       #
###############################################################################
print "Validating the new i2 Analyze Schema"
runi2AnalyzeTool "/opt/i2-tools/scripts/validateSchemaAndSecuritySchema.sh"

###############################################################################
# Generating update schema scripts                                            #
###############################################################################
print "Generating update schema scripts"
runi2AnalyzeTool "/opt/i2-tools/scripts/generateUpdateSchemaScripts.sh"

###############################################################################
# Running the generated scripts                                               #
###############################################################################
print "Running the generated scripts"
runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runDatabaseScripts.sh" "/opt/databaseScripts/generated/update"

###############################################################################
# Running the Liberty containers                                              #
###############################################################################
runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"
waitFori2AnalyzeServiceToBeLive

###############################################################################
# Validating database consistency                                             #
###############################################################################
print "Validating database consistency"
runi2AnalyzeTool "/opt/i2-tools/scripts/dbConsistencyCheckScript.sh"
