#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Set the root directory
ROOT_DIR=$(pwd)/../../../..

# Load common variables and functions
source ../../utils/commonVariables.sh
source ../../utils/commonFunctions.sh
source ../../utils/serverFunctions.sh
source ../../utils/clientFunctions.sh

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
