#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
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

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

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
