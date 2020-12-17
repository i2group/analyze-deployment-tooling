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
# Modifying the system match rules file                                       #
###############################################################################
print "Updating system-match-rules.xml"
cp "${LOCAL_CONFIG_CHANGES_DIR}/system-match-rules.xml" "${LOCAL_CONFIG_LIVE_DIR}"

###############################################################################
#  Uploading the system match rules                                           #
###############################################################################
print "Uploading system match rules"
runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" update_match_rules

###############################################################################
# Switching standby match index to live                                       #
###############################################################################
waitForIndexesToBeBuilt  "match_index2"
print "Switching standby match index to live"
runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live
