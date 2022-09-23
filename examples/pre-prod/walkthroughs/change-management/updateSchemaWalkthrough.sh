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
# Removing the Liberty containers                                                 #
###############################################################################
print "Removing the Liberty containers"
docker stop "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"
docker rm "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"

###############################################################################
# Modifying the schema                                                        #
###############################################################################
print "Making changes to the i2 Analyze Schema"
cp "${LOCAL_CONFIG_CHANGES_DIR}/schema.xml" "${LOCAL_CONFIG_COMMON_DIR}"
buildLibertyConfiguredImageForPreProd

###############################################################################
# Validating the schema                                                       #
###############################################################################
print "Validating the new i2 Analyze Schema"
run_i2_analyze_tool "/opt/i2-tools/scripts/validateSchemaAndSecuritySchema.sh"

###############################################################################
# Generating update schema scripts                                            #
###############################################################################
print "Generating update schema scripts"
run_i2_analyze_tool "/opt/i2-tools/scripts/generateUpdateSchemaScripts.sh"

###############################################################################
# Running the generated scripts                                               #
###############################################################################
print "Running the generated scripts"
run_sql_server_command_as_dba "/opt/databaseScripts/generated/runDatabaseScripts.sh" "/opt/databaseScripts/generated/update"

###############################################################################
# Running the Liberty containers                                              #
###############################################################################
runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_SECRETS_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_SECRETS_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"
waitFori2AnalyzeServiceToBeLive

###############################################################################
# Validating database consistency                                             #
###############################################################################
print "Validating database consistency"
run_i2_analyze_tool "/opt/i2-tools/scripts/dbConsistencyCheckScript.sh"

print_success "updateSchemaWalkthrough.sh has run successfully"
