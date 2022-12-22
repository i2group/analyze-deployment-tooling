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
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/common_functions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/server_functions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/client_functions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulated_external_variables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/common_variables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internal_helper_variables.sh"

warn_root_dir_not_in_path
set_dependencies_tag_if_necessary
# This allows us to version the backups of Solr and SQL server in the same way
# Note: Solr and SQL must be backed up as a pair and restored as a pair
backup_version=1

###############################################################################
# Set up backup permission                                                    #
###############################################################################
run_solr_container_with_backup_volume mkdir "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"
run_solr_container_with_backup_volume chown -R solr:0 "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"

###############################################################################
# Backing up Solr                                                             #
###############################################################################
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MAIN_INDEX_BACKUP_NAME}&name=${MAIN_INDEX_BACKUP_NAME}&collection=main_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MATCH_INDEX_BACKUP_NAME}&name=${MATCH_INDEX_BACKUP_NAME}&collection=match_index1&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${CHART_INDEX_BACKUP_NAME}&name=${CHART_INDEX_BACKUP_NAME}&collection=chart_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""

###############################################################################
# Monitoring Solr backup status                                               #
###############################################################################
wait_for_asynchronous_request_status_to_be_completed "${MATCH_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${CHART_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${MAIN_INDEX_BACKUP_NAME}"

###############################################################################
# Backing up system match rules file                                          #
###############################################################################
run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd getfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

###############################################################################
# Backing up SQL Server                                                       #
###############################################################################
print "Backing up the ISTORE database"

sql_query="\
    USE ISTORE;
        BACKUP DATABASE ISTORE
        TO DISK = '${DB_CONTAINER_BACKUP_DIR}/${backup_version}/${DB_BACKUP_FILE_NAME}'
        WITH FORMAT;"

run_sql_server_command_as_dbb run-sql-query "${sql_query}"

print_success "backup.sh has run successfully"
