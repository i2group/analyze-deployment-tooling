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

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "Please run '. initShell.sh' in your terminal first or set it with 'export ANALYZE_CONTAINERS_ROOT_DIR=<path_to_root>'"
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

# Local variable
MAX_TRIES=30

#######################################
# Wait for a specific i2 Analyze Service status.
# Arguments:
#   Status of i2 Analyze service to wait-for
#   -> Could be either 'Active', 'Down' or 'Degraded'.
#######################################
function waitFori2AnalyzeServiceStatus() {
  local expected_status="$1"
  local i2Analyze_service_status
  local tries=1
  local max_tries=30

  print "Waiting for i2 Analyze service to be ${expected_status}"
  while [[ "${tries}" -le "${max_tries}" ]]; do
    i2Analyze_service_status="$(geti2AnalyzeServiceStatus)"
    if [[ "${i2Analyze_service_status}" == "${expected_status}" ]]; then
      echo "i2 Analyze service status: '${i2Analyze_service_status}'"
      break
    fi
    echo "i2 Analyze service status: '${i2Analyze_service_status}'"
    echo "Waiting..."
    sleep 5
    if [[ "${tries}" -ge "${max_tries}" ]]; then
      printErrorAndExit "ERROR: i2 Analyze service status: '${i2Analyze_service_status}'"
    fi
    tries=$((tries + 1))
  done
}

###############################################################################
# Identifying the Liberty leader                                              #
###############################################################################
print "Identifying the Liberty leader"
if grep -q "We are the Liberty leader" <<<"$(docker logs "${LIBERTY1_CONTAINER_NAME}" 2>&1)"; then
  LEADER_LIBERTY="${LIBERTY1_CONTAINER_NAME}"
  NON_LEADER_LIBERTY="${LIBERTY2_CONTAINER_NAME}"
elif grep -q "We are the Liberty leader" <<<"$(docker logs "${LIBERTY2_CONTAINER_NAME}" 2>&1)"; then
  LEADER_LIBERTY="${LIBERTY2_CONTAINER_NAME}"
  NON_LEADER_LIBERTY="${LIBERTY1_CONTAINER_NAME}"
else
  echo "Could NOT identify leader Liberty"
  exit 1
fi
echo "${LEADER_LIBERTY} is the leader Liberty"
echo "${NON_LEADER_LIBERTY} is the non-leader Liberty"

###############################################################################
# Simulating leader Liberty failure                                           #
###############################################################################
print "Simulating leader Liberty failure"
echo "Stopping leader Liberty container"
docker stop "${LEADER_LIBERTY}"

###############################################################################
# Detecting failure                                                           #
###############################################################################
waitFori2AnalyzeServiceStatus "DEGRADED"

###############################################################################
# Fail over                                                                   #
###############################################################################
print "Waiting for ${NON_LEADER_LIBERTY} to become a leader"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  if grep -q "We are the Liberty leader" <<<"$(docker logs "${NON_LEADER_LIBERTY}" 2>&1)"; then
    echo "${NON_LEADER_LIBERTY} is the new leader Liberty"
    echo "Message:"
    grep "We are the Liberty leader" <<<"$(docker logs "${NON_LEADER_LIBERTY}" 2>&1)"
    break
  fi
  echo "Waiting..."
  sleep 5
  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "${NON_LEADER_LIBERTY} is NOT a new leader"
  fi
  ((TRIES++))
done

###############################################################################
# Re-instating high availability                                              #
###############################################################################
print "Re-instating high availability"
echo "Starting ${LEADER_LIBERTY} container"
docker start "${LEADER_LIBERTY}"

waitFori2AnalyzeServiceStatus "ACTIVE"

print "Making sure ${LEADER_LIBERTY} is not the Liberty leader"
TRIES=1
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  if grep -q "We are not the Liberty leader" <<<"$(docker logs "${LEADER_LIBERTY}" 2>&1)"; then
    echo "${LEADER_LIBERTY} is not the leader Liberty"
    echo "Message:"
    grep "We are not the Liberty leader" <<<"$(docker logs "${LEADER_LIBERTY}" 2>&1)"
    break
  fi
  echo "Waiting..."
  sleep 5
  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "${LEADER_LIBERTY} is NOT a new leader"
  fi
  ((TRIES++))
done

print "SUCCESS: libertyHadrFailureWalkthrough has run successfully"
