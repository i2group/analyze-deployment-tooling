#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
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
# Running a new Solr container                                                #
###############################################################################
print "Running a new Solr container"
run_solr "${SOLR3_CONTAINER_NAME}" "${SOLR3_FQDN}" "${SOLR3_VOLUME_NAME}" 8985 "solr3"
wait_for_solr_to_be_live "${SOLR3_FQDN}"

###############################################################################
# Adding a Solr replica                                                       #
###############################################################################
print "Adding a Solr replica"

# The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
# Any double quotes in the curl command are also escaped by a leading backslash.
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=ADDREPLICA&collection=main_index&shard=shard1&node=${SOLR3_FQDN}:8983_solr\""

print_success "addSolrNodeWalkthrough.sh has run successfully"
