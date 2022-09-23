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
# Local variables
TRIES=1
MAX_TRIES=30

###############################################################################
# Simulating Solr node failure                                                #
###############################################################################
print "Simulating Solr node failure"
SINCE_TIMESTAMP="$(getTimestamp)"
docker stop "${SOLR2_CONTAINER_NAME}"

###############################################################################
# Detecting failure                                                           #
###############################################################################
print "Waiting for Liberty to mark the collection as unhealthy"
TRIES=1
echo "${SINCE_TIMESTAMP}"
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  echo "Looking for collection is not healthy message..."
  status_message="$(get_solr_status "${SINCE_TIMESTAMP}")"

  if grep -q "DEGRADED" <<<"${status_message}"; then
    echo "Solr has been marked as DEGRADED"
    echo "Message: ${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    print_error_and_exit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show that the solr cluster has lost one replica"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Start the Solr container                                                    #
###############################################################################
print "Reinstating high availability by starting ${SOLR2_CONTAINER_NAME}"
SINCE_TIMESTAMP="$(getTimestamp)"
docker start "${SOLR2_CONTAINER_NAME}"

###############################################################################
# Monitor for healthy collection                                              #
###############################################################################
print "Waiting for Liberty to mark the collection as healthy"
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  echo "Looking for collection is healthy message..."
  status_message="$(get_solr_status "${SINCE_TIMESTAMP}")"

  if grep -q "ACTIVE" <<<"${status_message}"; then
    echo "Solr collection has been marked as healthy"
    echo "Message: ${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    print_error_and_exit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show that the solr cluster has recovered"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

print_success "solrNodeFailureWalkthrough has run successfully"
