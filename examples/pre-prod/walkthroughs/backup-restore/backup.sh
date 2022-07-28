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
# This allows us to version the backups of Solr and SQL server in the same way
# Note: Solr and SQL must be backed up as a pair and restored as a pair
backup_version=1

###############################################################################
# Set up backup permission                                                    #
###############################################################################
runSolrContainerWithBackupVolume mkdir "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"
runSolrContainerWithBackupVolume chown -R solr:0 "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"

###############################################################################
# Backing up Solr                                                             #
###############################################################################
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MAIN_INDEX_BACKUP_NAME}&name=${MAIN_INDEX_BACKUP_NAME}&collection=main_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MATCH_INDEX_BACKUP_NAME}&name=${MATCH_INDEX_BACKUP_NAME}&collection=match_index1&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${CHART_INDEX_BACKUP_NAME}&name=${CHART_INDEX_BACKUP_NAME}&collection=chart_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""

###############################################################################
# Monitoring backup status                                                    #
###############################################################################
waitForAsynchronousRequestStatusToBeCompleted "${MATCH_INDEX_BACKUP_NAME}"
waitForAsynchronousRequestStatusToBeCompleted "${CHART_INDEX_BACKUP_NAME}"
waitForAsynchronousRequestStatusToBeCompleted "${MAIN_INDEX_BACKUP_NAME}"

###############################################################################
# Backup system-match-rules status                                            #
###############################################################################
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd getfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

###############################################################################
# Backing up SQL Server                                                       #
###############################################################################
print "Backing up the ISTORE database"

sql_query="\
    USE ISTORE;
        BACKUP DATABASE ISTORE
        TO DISK = '${DB_CONTAINER_BACKUP_DIR}/${backup_version}/${DB_BACKUP_FILE_NAME}'
        WITH FORMAT;"

runSQLServerCommandAsDBB runSQLQuery "${sql_query}"
