#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

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
