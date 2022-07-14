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
