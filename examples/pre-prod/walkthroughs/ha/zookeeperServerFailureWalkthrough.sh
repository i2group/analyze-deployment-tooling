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
  if grep -q "DEGRADED" <<<"$(getZkQuorumEnsembleStatus)"; then
    echo "The Zookeeper ensemble is DEGRADED, a server is missing"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "The ZooKeeper ensemble did not report any degradation"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Reinstating high availability                                              #
###############################################################################
print "Re-instating high availability"
echo "Starting up ZooKeeper container (${ZK1_CONTAINER_NAME})"
docker start "${ZK1_CONTAINER_NAME}"

print "Waiting for the ZooKeeper ensemble status to be ACTIVE"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  if grep -q "ACTIVE" <<<"$(getZkQuorumEnsembleStatus)"; then
    echo "The ZooKeeper quorum is ACTIVE, all servers are running"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "ZooKeeper ensemble did come back correctly"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

print "SUCCESS: zookeeperServerFailureWalkthrough has run successfully"
