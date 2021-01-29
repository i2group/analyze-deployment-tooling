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
ROOT_DIR=$(pwd)/../../..

# Load common variables and functions
source ../utils/commonVariables.sh
source ../utils/commonFunctions.sh
source ../utils/serverFunctions.sh
source ../utils/clientFunctions.sh

###############################################################################
# Reset the configuration                                                     #
###############################################################################
print "Resetting configuration"
./../createConfiguration.sh

###############################################################################
# Reset the deployment                                                        #
###############################################################################
print "Rerunning deploy.sh"
./../deploy.sh
