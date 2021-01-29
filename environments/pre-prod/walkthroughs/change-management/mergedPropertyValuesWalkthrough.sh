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
# Enabling merged property values                                             #
###############################################################################
print "Enabling merged property values for Person entity type"
runEtlToolkitToolAsDBA bash -c "/opt/ibm/etltoolkit/enableMergedPropertyValues --schemaTypeId ET5"

###############################################################################
# Updating property value definitions                                         #
###############################################################################
print "Updating configuration with the createAlternativeMergedPropertyValuesView.sql file from ${LOCAL_CONFIG_CHANGES_DIR}"
cp "${LOCAL_CONFIG_CHANGES_DIR}/createAlternativeMergedPropertyValuesView.sql" "${LOCAL_GENERATED_DIR}"
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
runSQLServerCommandAsDBA bash -c "${SQLCMD} ${SQLCMD_FLAGS} -S \${DB_SERVER},\${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} -i /opt/databaseScripts/generated/createAlternativeMergedPropertyValuesView.sql"

###############################################################################
# Reingesting the data                                                       #
###############################################################################
print "Reingesting the data"
./ingestDataWalkthrough.sh
