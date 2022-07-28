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
# Local variables
TRIES=1
MAX_TRIES=30

###############################################################################
# Simulating ZooKeeper quorum failure                                         #
###############################################################################
print "Simulating a ZooKeeper quorum failure"
SINCE_TIMESTAMP="$(getTimestamp)"
echo "Stopping 2 ZooKeeper Servers (>50% of the quorum members)"
docker stop "${ZK1_CONTAINER_NAME}" "${ZK2_CONTAINER_NAME}"

###############################################################################
# Detecting failure                                                           #
###############################################################################
print "Waiting for Liberty to mark the Solr cluster as unavailable"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  echo "Looking for collection is not healthy message..."
  status_message="$(getSolrStatus "${SINCE_TIMESTAMP}")"

  if grep -q "DOWN" <<<"$(getSolrStatus "${SINCE_TIMESTAMP}")"; then
    echo "Solr services are unavailable"
    echo "Message:"
    grep "DOWN" <<<"${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show Solr is DOWN"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Reinstating high availability                                               #
###############################################################################
print "Starting up ZooKeeper containers"
SINCE_TIMESTAMP="$(getTimestamp)"
docker start "${ZK1_CONTAINER_NAME}" "${ZK2_CONTAINER_NAME}"

print "Waiting for Liberty to mark the Solr collection as healthy"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  echo "Looking for collection is healthy message..."
  status_message="$(getSolrStatus "${SINCE_TIMESTAMP}")"

  if grep -q "ACTIVE" <<<"$(getSolrStatus "${SINCE_TIMESTAMP}")"; then
    echo "Solr collection has been marked as healthy"
    echo "Message:"
    grep "ACTIVE" <<<"${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show that the Solr cluster has recovered"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

print "SUCCESS: zookeeperQuorumFailureWalkthrough has run successfully"
