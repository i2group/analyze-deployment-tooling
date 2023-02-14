#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
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
source "${ANALYZE_CONTAINERS_ROOT_DIR}/version.conf"

warn_root_dir_not_in_path
set_dependencies_tag_if_necessary
backup_version=upgrade

###############################################################################
# Restart Pre-Prod Container                                                  #
###############################################################################
start_container "${ZK1_CONTAINER_NAME}"
start_container "${ZK2_CONTAINER_NAME}"
start_container "${ZK3_CONTAINER_NAME}"
start_container "${SOLR1_CONTAINER_NAME}"
start_container "${SOLR2_CONTAINER_NAME}"
wait_for_solr_to_be_live "${SOLR1_FQDN}"
start_container "${SQL_SERVER_CONTAINER_NAME}"
wait_for_sql_server_to_be_live
start_container "${CONNECTOR1_CONTAINER_NAME}"
start_container "${LIBERTY1_CONTAINER_NAME}"
start_container "${LIBERTY2_CONTAINER_NAME}"
start_container "${LOAD_BALANCER_CONTAINER_NAME}"
wait_for_i2_analyze_service_to_be_live

###############################################################################
# Backing up Solr                                                             #
###############################################################################
print "Backing up Solr"
# Set up backup permission
run_solr_container_with_backup_volume mkdir -p "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"
run_solr_container_with_backup_volume chown -R solr:0 "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}"

# Backing up Solr
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MAIN_INDEX_BACKUP_NAME}&name=${MAIN_INDEX_BACKUP_NAME}&collection=main_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${MATCH_INDEX_BACKUP_NAME}&name=${MATCH_INDEX_BACKUP_NAME}&collection=match_index1&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=BACKUP&async=${CHART_INDEX_BACKUP_NAME}&name=${CHART_INDEX_BACKUP_NAME}&collection=chart_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""

# Monitoring backup status
wait_for_asynchronous_request_status_to_be_completed "${MATCH_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${CHART_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${MAIN_INDEX_BACKUP_NAME}"

# Backup system-match-rules status
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

###############################################################################
# Rebuilding images                                                           #
###############################################################################
print "Running build-images"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/scripts/build-images" -e "${ENVIRONMENT}"

###############################################################################
# Run change set tool                                                         #
###############################################################################
print "Running create-change-set"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/scripts/create-change-set" -e "${ENVIRONMENT}" -t "upgrade"

###############################################################################
# Removing the previous containers                                            #
###############################################################################
print "Removing the previous containers"
delete_container "${SOLR1_CONTAINER_NAME}"
delete_container "${SOLR2_CONTAINER_NAME}"
delete_container "${ZK1_CONTAINER_NAME}"
delete_container "${ZK2_CONTAINER_NAME}"
delete_container "${ZK3_CONTAINER_NAME}"
delete_container "${SQL_SERVER_CONTAINER_NAME}"
delete_container "${LIBERTY1_CONTAINER_NAME}"
delete_container "${LIBERTY2_CONTAINER_NAME}"
delete_container "${LOAD_BALANCER_CONTAINER_NAME}"
delete_container "${CONNECTOR1_CONTAINER_NAME}"
delete_container "${PROMETHEUS_CONTAINER_NAME}"
delete_container "${GRAFANA_CONTAINER_NAME}"

quietly_remove_docker_volume "${SOLR1_VOLUME_NAME}"
quietly_remove_docker_volume "${SOLR2_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK1_DATA_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK2_DATA_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK3_DATA_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK1_DATALOG_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK2_DATALOG_VOLUME_NAME}"
quietly_remove_docker_volume "${ZK3_DATALOG_VOLUME_NAME}"
quietly_remove_docker_volume "${SQL_SERVER_VOLUME_NAME}"
quietly_remove_docker_volume "${LOAD_BALANCER_VOLUME_NAME}"
quietly_remove_docker_volume "${GRAFANA_DATA_VOLUME_NAME}"

###############################################################################
# Upgrading Solr                                                              #
###############################################################################
# Deploying new Solr and ZooKeeper
print "Running Zookeeper containers"
run_zk "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" "${ZK1_DATA_VOLUME_NAME}" "${ZK1_DATALOG_VOLUME_NAME}" "${ZK1_LOG_VOLUME_NAME}" 1 "zk1" "${ZK1_SECRETS_VOLUME_NAME}"
run_zk "${ZK2_CONTAINER_NAME}" "${ZK2_FQDN}" "${ZK2_DATA_VOLUME_NAME}" "${ZK2_DATALOG_VOLUME_NAME}" "${ZK2_LOG_VOLUME_NAME}" 2 "zk2" "${ZK2_SECRETS_VOLUME_NAME}"
run_zk "${ZK3_CONTAINER_NAME}" "${ZK3_FQDN}" "${ZK3_DATA_VOLUME_NAME}" "${ZK3_DATALOG_VOLUME_NAME}" "${ZK3_LOG_VOLUME_NAME}" 3 "zk3" "${ZK3_SECRETS_VOLUME_NAME}"

print "Configuring ZK Cluster for Solr"
run_solr_client_command solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
if [[ "${SOLR_ZOO_SSL_CONNECTION}" == true ]]; then
  run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
fi
run_solr_client_command bash -c "echo \"\${SECURITY_JSON}\" > /tmp/security.json && solr zk cp /tmp/security.json zk:/security.json -z ${ZK_HOST}"

print "Configuring Solr collections"
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /opt/configuration/solr/generated_config/daod_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n main_index -d /opt/configuration/solr/generated_config/main_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n chart_index -d /opt/configuration/solr/generated_config/chart_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n highlight_index -d /opt/configuration/solr/generated_config/highlight_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n match_index1 -d /opt/configuration/solr/generated_config/match_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n match_index2 -d /opt/configuration/solr/generated_config/match_index
run_solr_client_command solr zk upconfig -v -z "${ZK_HOST}" -n vq_index -d /opt/configuration/solr/generated_config/vq_index

print "Running secure Solr containers"
run_solr "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" "${SOLR1_VOLUME_NAME}" 8983 "solr1" "${SOLR1_SECRETS_VOLUME_NAME}"
run_solr "${SOLR2_CONTAINER_NAME}" "${SOLR2_FQDN}" "${SOLR2_VOLUME_NAME}" 8984 "solr2" "${SOLR2_SECRETS_VOLUME_NAME}"
wait_for_solr_to_be_live "${SOLR1_FQDN}"

###############################################################################
# Restoring Solr                                                              #
###############################################################################

# Restoring non-transient Solr collection
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${MAIN_INDEX_BACKUP_NAME}&name=${MAIN_INDEX_BACKUP_NAME}&collection=main_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${MATCH_INDEX_BACKUP_NAME}&name=${MATCH_INDEX_BACKUP_NAME}&collection=match_index1&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${CHART_INDEX_BACKUP_NAME}&name=${CHART_INDEX_BACKUP_NAME}&collection=chart_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""

# Monitoring Solr restore process
wait_for_asynchronous_request_status_to_be_completed "${MATCH_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${CHART_INDEX_BACKUP_NAME}"
wait_for_asynchronous_request_status_to_be_completed "${MAIN_INDEX_BACKUP_NAME}"

# Recreating transient Solr collections
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=daod_index&collection.configName=daod_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=highlight_index&collection.configName=highlight_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index2&collection.configName=match_index2&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=vq_index&collection.configName=vq_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""

# Restoring system match rules
run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd makepath /configs/match_index1/match_index1/app
run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd putfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

###############################################################################
# Upgrading Information Store                                                 #
###############################################################################
print "Upgrading Information Store"

print "Running a new SQL Server"
run_sql_server
wait_for_sql_server_to_be_live "true"
change_sa_password

print "Restoring the Information Store database"

sql_query="\
  RESTORE DATABASE ISTORE FROM DISK = '${DB_CONTAINER_BACKUP_DIR}/${backup_version}/${DB_BACKUP_FILE_NAME}';"
run_sql_server_command_as_sa run-sql-query "${sql_query}"

# Dropping existing database users
print "Dropping ISTORE users"

sql_query="\
  USE ISTORE;
      DROP USER dba;
      DROP USER i2analyze;
          DROP USER i2etl;
          DROP USER etl;
              DROP USER dbb;"
run_sql_server_command_as_sa run-sql-query "${sql_query}"

# Recreating database logins, users, and permissions
print "Creating database logins and users"
create_db_login_and_user "dbb" "db_backupoperator"
create_db_login_and_user "dba" "DBA_Role"
create_db_login_and_user "i2analyze" "i2Analyze_Role"
create_db_login_and_user "i2etl" "i2_ETL_Role"
create_db_login_and_user "etl" "External_ETL_Role"
run_sql_server_command_as_sa "/opt/db-scripts/configure_dba_roles_and_permissions.sh"
run_sql_server_command_as_sa "/opt/db-scripts/add_etl_user_to_sys_admin_role.sh"

print "Running upgrade scripts"
run_sql_server_command_as_dba "/opt/databaseScripts/generated/runDatabaseScripts.sh" "/opt/databaseScripts/generated/upgrade"

###############################################################################
# Upgrading Example Connector                                                 #
###############################################################################
run_example_connector "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_FQDN}" "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_SECRETS_VOLUME_NAME}"
wait_for_connector_to_be_live "${CONNECTOR1_FQDN}"

###############################################################################
# Upgrading Liberty                                                           #
###############################################################################
print "Upgrading Liberty"

build_liberty_configured_image_for_pre_prod
run_liberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_SECRETS_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_DEBUG_PORT}"
run_liberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_SECRETS_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_DEBUG_PORT}"
run_load_balancer
wait_for_i2_analyze_service_to_be_live

###############################################################################
# Upgrading Prometheus                                                        #
###############################################################################
print "Upgrading Prometheus"
# Ensure volume has the correct permissions
docker run --rm \
    -v "${PROMETHEUS_DATA_VOLUME_NAME}:/prometheus" \
    --user="root" \
    --entrypoint="" \
    "${PROMETHEUS_IMAGE_NAME}:${PROMETHEUS_VERSION}" chown -R prometheus:0 "/prometheus"
configure_prometheus_for_pre_prod
run_prometheus
wait_for_prometheus_server_to_be_live

###############################################################################
# Upgrading Grafana                                                           #
###############################################################################
print "Upgrading Grafana"

run_grafana
wait_for_grafana_server_to_be_live

###############################################################################
# Updating version file                                                       #
###############################################################################
sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" \
  "${LOCAL_CONFIGURATION_DIR}/version.conf"

print_success "upgradeWalkthrough.sh has run successfully"
