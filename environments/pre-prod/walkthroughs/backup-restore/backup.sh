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
waitForAsyncrhonousRequestStatusToBeCompleted "${MATCH_INDEX_BACKUP_NAME}"
waitForAsyncrhonousRequestStatusToBeCompleted "${CHART_INDEX_BACKUP_NAME}"
waitForAsyncrhonousRequestStatusToBeCompleted "${MAIN_INDEX_BACKUP_NAME}"

###############################################################################
# Backup system-match-rules status                                            #
###############################################################################
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd getfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

###############################################################################
# Backing up SQL Server                                                       #
###############################################################################
print "Backing up the ISTORE database"
runSQLServerCommandAsDBB bash -c "${SQLCMD} ${SQLCMD_FLAGS} -C -S ${SQL_SERVER_FQDN},${DB_PORT} -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" \
    -Q \"USE ISTORE; 
        BACKUP DATABASE ISTORE
        TO DISK = '${DB_CONTAINER_BACKUP_DIR}/${backup_version}/${DB_BACKUP_FILE_NAME}'
            WITH FORMAT;\""
