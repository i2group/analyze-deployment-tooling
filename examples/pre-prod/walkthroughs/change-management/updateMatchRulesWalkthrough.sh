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
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/common_functions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/server_functions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/client_functions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulated_external_variables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/common_variables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internal_helper_variables.sh"

warn_root_dir_not_in_path
set_dependencies_tag_if_necessary
###############################################################################
# Modifying the system match rules file                                       #
###############################################################################
print "Updating system-match-rules.xml"
cp "${LOCAL_CONFIG_CHANGES_DIR}/system-match-rules.xml" "${LOCAL_CONFIG_LIVE_DIR}"

###############################################################################
#  Uploading the system match rules                                           #
###############################################################################
print "Uploading system match rules"
run_i2_analyze_tool "/opt/i2-tools/scripts/runIndexCommand.sh" update_match_rules

###############################################################################
# Switching standby match index to live                                       #
###############################################################################
wait_for_indexes_to_be_built "match_index2"
print "Switching standby match index to live"
run_i2_analyze_tool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live

print_success "updateMatchRulesWalkthrough.sh has run successfully"
