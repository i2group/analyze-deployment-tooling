#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
set -e

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
# Simulating the cluster failure                                              #
###############################################################################
print "Simulating Cluster failure"
SINCE_TIMESTAMP="$(getTimestamp)"
docker stop "${SOLR2_CONTAINER_NAME}" "${SOLR1_CONTAINER_NAME}"

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
    printErrorAndExit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show solr is DOWN"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Re-instating high availability                                              #
###############################################################################
print "Re-instating HA by starting solr's"
SINCE_TIMESTAMP="$(getTimestamp)"
docker start "${SOLR2_CONTAINER_NAME}" "${SOLR1_CONTAINER_NAME}"

print "Waiting for Liberty to mark the collection as healthy"
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
    printErrorAndExit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show that the solr cluster has recovered"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

print "SUCCESS: solrClusterFailureWalkthrough has run successfully"
