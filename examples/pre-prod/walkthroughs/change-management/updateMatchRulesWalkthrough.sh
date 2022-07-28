#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "This project should be run inside a VSCode Dev Container. For more information read, the Getting Started guide at https://i2group.github.io/analyze-containers/content/getting_started.html"
  exit 1
fi

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

warnRootDirNotInPath
setDependenciesTagIfNecessary
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
waitForIndexesToBeBuilt "match_index2"
print "Switching standby match index to live"
runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live
