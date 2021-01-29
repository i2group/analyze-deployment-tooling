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
  local i2Analzye_service_status
  local tries=1
  local max_tries=30

  print "Waiting for i2 Analyze service to be ${expected_status}"
  while [[ "${tries}" -le "${max_tries}" ]]; do
    i2Analzye_service_status="$(geti2AnalyzeServiceStatus)"
    if [[ "${i2Analzye_service_status}" == "${expected_status}" ]]; then
      echo "i2 Analyze service status: '${i2Analzye_service_status}'"
      break
    fi
    echo "i2 Analyze service status: '${i2Analzye_service_status}'"
    echo "Waiting..."
    sleep 5
    if [[ "${tries}" -ge "${max_tries}" ]]; then
      printErrorAndExit "ERROR: i2 Analyze service status: '${i2Analzye_service_status}'"
    fi
    ((tries++))
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
