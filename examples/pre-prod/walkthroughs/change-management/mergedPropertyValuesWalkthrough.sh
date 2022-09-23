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
# Enabling merged property values                                             #
###############################################################################
print "Enabling merged property values for Person entity type"
run_etl_toolkit_tool_as_dba bash -c "/opt/i2/etltoolkit/enableMergedPropertyValues --schemaTypeId ET5"

###############################################################################
# Updating property value definitions                                         #
###############################################################################
print "Updating configuration with the createAlternativeMergedPropertyValuesView.sql file from ${LOCAL_CONFIG_CHANGES_DIR}"
cp "${LOCAL_CONFIG_CHANGES_DIR}/createAlternativeMergedPropertyValuesView.sql" "${LOCAL_GENERATED_DIR}"
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
run_sql_server_command_as_dba bash -c "${SQLCMD} ${SQLCMD_FLAGS} -S \${DB_SERVER},\${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} -i /opt/databaseScripts/generated/createAlternativeMergedPropertyValuesView.sql"

###############################################################################
# Reingesting the data                                                       #
###############################################################################
print "Reingesting the data"
"${PRE_PROD_DIR}/walkthroughs/change-management/ingestDataWalkthrough.sh"

print_success "mergedPropertyValuesWalkthrough.sh has run successfully"
