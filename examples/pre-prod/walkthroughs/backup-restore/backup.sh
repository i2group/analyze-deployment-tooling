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
runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd getfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

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
