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
###############################################################################
# Removing the Liberty containers                                             #
###############################################################################
print "Removing the Liberty containers"
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
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index1/collectionprops.json"
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/chart_index/collectionprops.json"

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
runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_SECRETS_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
### Run liberty2
runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_SECRETS_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"

waitFori2AnalyzeServiceToBeLive
