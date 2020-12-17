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
cd "${SCRIPT_DIR}"

# Set the root directory
ROOT_DIR=$(pwd)/../../../..

# Load common variables and functions
source ../../utils/commonVariables.sh
source ../../utils/commonFunctions.sh
source ../../utils/serverFunctions.sh
source ../../utils/clientFunctions.sh

###############################################################################
# Stopping the Liberty containers                                             #
###############################################################################
docker stop "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"
docker rm "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"

###############################################################################
# Clearing the search index                                                   #
###############################################################################
### Delete all of the documents in each collection
print "Clearing the search index"
# The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
# Any double quotes in the curl command are also escaped by a leading backslash.
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/main_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index1/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index2/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/chart_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/daod_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/highlight_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""

# Remove the collection properties from ZooKeeper
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index1/collectionprops.json"
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/chart_index/collectionprops.json"

###############################################################################
# Clearing the Information Store database                                     #
###############################################################################
print "Clearing the InfoStore database"
### Run runClearInfoStoreData.sh tool
runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runClearInfoStoreData.sh"

###############################################################################
# Running the Liberty containers                                              #
###############################################################################
### Run liberty1
runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
### Run liberty2
runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"

waitFori2AnalyzeServiceToBeLive
