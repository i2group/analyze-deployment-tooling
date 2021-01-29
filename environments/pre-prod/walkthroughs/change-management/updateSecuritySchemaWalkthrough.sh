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
# Modifying the security schema file                                          #
###############################################################################
print "Making changes to the i2Analyze security schema file"
cp "${LOCAL_CONFIG_CHANGES_DIR}/security-schema.xml" "${LOCAL_CONFIG_COMMON_DIR}"
buildLibertyConfiguredImage

###############################################################################
# Validating the security schema                                              #
###############################################################################
print "Validating the new security schema"
runi2AnalyzeTool "/opt/i2-tools/scripts/validateSchemaAndSecuritySchema.sh"

###############################################################################
# Updating the Information Store                                              #
###############################################################################
print "Updating the Information Store"
runi2AnalyzeTool "/opt/i2-tools/scripts/updateSecuritySchema.sh"

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
