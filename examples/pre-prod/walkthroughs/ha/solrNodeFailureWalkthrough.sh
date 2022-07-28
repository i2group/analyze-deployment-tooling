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
# Simulating node failure                                                     #
###############################################################################
print "Simulating node failure"
SINCE_TIMESTAMP="$(getTimestamp)"
docker stop "${SOLR2_CONTAINER_NAME}"

###############################################################################
# Monitor for unhealthy collection                                            #
###############################################################################
print "Waiting for Liberty to mark the collection as unhealthy"
TRIES=1
echo "${SINCE_TIMESTAMP}"
while [[ "${TRIES}" -le "${MAX_TRIES}" ]]; do
  echo "Looking for collection is not healthy message..."
  status_message="$(getSolrStatus "${SINCE_TIMESTAMP}")"

  if grep -q "DEGRADED" <<<"$(getSolrStatus "${SINCE_TIMESTAMP}")"; then
    echo "Solr has been marked as DEGRADED"
    echo "Message:"
    grep "DEGRADED" <<<"${status_message}"
    break
  fi

  if [[ "${TRIES}" -ge "${MAX_TRIES}" ]]; then
    printErrorAndExit "Liberty container (${LIBERTY1_CONTAINER_NAME}) does NOT show that the solr cluster has lost one replica"
  fi
  echo "Waiting..."
  sleep 5
  ((TRIES++))
done

###############################################################################
# Start the Solr container                                                    #
###############################################################################
print "Re-instating HA by starting solr2"
SINCE_TIMESTAMP="$(getTimestamp)"
docker start "${SOLR2_CONTAINER_NAME}"

###############################################################################
# Monitor for healthy collection                                              #
###############################################################################
print "Waiting for Liberty to mark the collection as healthy"
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

print "SUCCESS: solrNodeFailureWalkthrough has run successfully"
