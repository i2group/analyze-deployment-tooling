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
# Simulating ZooKeeper server failure                                         #
###############################################################################
print "Simulating a ZooKeeper server failure"
echo "Stopping (${ZK1_CONTAINER_NAME})"
docker stop "${ZK1_CONTAINER_NAME}"

###############################################################################
# Detecting failure                                                           #
###############################################################################
print "Waiting for the ZooKeeper quorum status to be DEGRADED"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  status_message="$(getZkQuorumEnsembleStatus)"
  if grep -q "DEGRADED" <<<"${status_message}"; then
    echo "The Zookeeper ensemble is DEGRADED, a server is missing"
    echo "Message: ${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    print_error_and_exit "The ZooKeeper ensemble did not report any degradation"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Reinstating high availability                                               #
###############################################################################
print "Reinstating high availability by starting ${ZK1_CONTAINER_NAME}"
docker start "${ZK1_CONTAINER_NAME}"

print "Waiting for the ZooKeeper ensemble status to be ACTIVE"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  status_message="$(getZkQuorumEnsembleStatus)"
  if grep -q "ACTIVE" <<<"${status_message}"; then
    echo "The ZooKeeper quorum is ACTIVE, all servers are running"
    echo "Message: ${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    print_error_and_exit "ZooKeeper ensemble did come back correctly"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

print_success "zookeeperServerFailureWalkthrough has run successfully"
