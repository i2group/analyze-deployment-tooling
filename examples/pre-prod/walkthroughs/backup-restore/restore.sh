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
# Note: If changing the version of the back up, ensure this value matches.
backup_version=1

###############################################################################
# Removing Solr, ZooKeeper, and SQL Server                                    #
###############################################################################
print "Cleaning down"
docker container stop "${SOLR1_CONTAINER_NAME}" "${SOLR2_CONTAINER_NAME}" "${ZK1_CONTAINER_NAME}" "${ZK2_CONTAINER_NAME}" "${ZK3_CONTAINER_NAME}" "${SQL_SERVER_CONTAINER_NAME}"
docker container rm "${SOLR1_CONTAINER_NAME}" "${SOLR2_CONTAINER_NAME}" "${ZK1_CONTAINER_NAME}" "${ZK2_CONTAINER_NAME}" "${ZK3_CONTAINER_NAME}" "${SQL_SERVER_CONTAINER_NAME}"

quietlyRemoveDockerVolume "${SOLR1_VOLUME_NAME}"
quietlyRemoveDockerVolume "${SOLR2_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK1_DATA_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK2_DATA_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK3_DATA_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK1_DATALOG_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK2_DATALOG_VOLUME_NAME}"
quietlyRemoveDockerVolume "${ZK3_DATALOG_VOLUME_NAME}"
quietlyRemoveDockerVolume "${SQL_SERVER_VOLUME_NAME}"

###############################################################################
# Stop the Liberty containers                                                 #
###############################################################################
print "Stopping Liberty containers"
docker container stop "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"

###############################################################################
# Running SQL Server                                                          #
###############################################################################
print "Running a new SQL Server"
runSQLServer
waitForSQLServerToBeLive "true"
changeSAPassword

###############################################################################
# Restoring the ISTORE database                                               #
###############################################################################
print "Restoring the ISTORE database"

sql_query="\
  RESTORE DATABASE ISTORE FROM DISK = '${DB_CONTAINER_BACKUP_DIR}/${backup_version}/${DB_BACKUP_FILE_NAME}';"
runSQLServerCommandAsSA runSQLQuery "${sql_query}"

###############################################################################
# Dropping existing database users                                            #
###############################################################################
print "Dropping ISTORE users"

sql_query="\
  USE ISTORE;
    DROP USER dba;
      DROP USER i2analyze;
        DROP USER i2etl;
          DROP USER etl;
            DROP USER dbb;"
runSQLServerCommandAsSA runSQLQuery "${sql_query}"

###############################################################################
# Recreating database logins, users, and permissions                          #
###############################################################################

print "Creating database logins and users"
createDbLoginAndUser "dbb" "db_backupoperator"
createDbLoginAndUser "dba" "DBA_Role"
createDbLoginAndUser "i2analyze" "i2Analyze_Role"
createDbLoginAndUser "i2etl" "i2_ETL_Role"
createDbLoginAndUser "etl" "External_ETL_Role"
runSQLServerCommandAsSA "/opt/db-scripts/configureDbaRolesAndPermissions.sh"
runSQLServerCommandAsSA "/opt/db-scripts/addEtlUserToSysAdminRole.sh"

###############################################################################
# Deploying new Solr and ZooKeeper                                            #
###############################################################################
print "Running Zookeeper containers"
runZK "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" "${ZK1_DATA_VOLUME_NAME}" "${ZK1_DATALOG_VOLUME_NAME}" "${ZK1_LOG_VOLUME_NAME}" "1" "zk1" "${ZK1_SECRETS_VOLUME_NAME}"
runZK "${ZK2_CONTAINER_NAME}" "${ZK2_FQDN}" "${ZK2_DATA_VOLUME_NAME}" "${ZK2_DATALOG_VOLUME_NAME}" "${ZK2_LOG_VOLUME_NAME}" "2" "zk2" "${ZK2_SECRETS_VOLUME_NAME}"
runZK "${ZK3_CONTAINER_NAME}" "${ZK3_FQDN}" "${ZK3_DATA_VOLUME_NAME}" "${ZK3_DATALOG_VOLUME_NAME}" "${ZK3_LOG_VOLUME_NAME}" "3" "zk3" "${ZK3_SECRETS_VOLUME_NAME}"

print "Configuring ZK Cluster for Solr"
runSolrClientCommand solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
if [[ "${SOLR_ZOO_SSL_CONNECTION}" == true ]]; then
  runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
fi
runSolrClientCommand bash -c "echo \"\${SECURITY_JSON}\" > /tmp/security.json && solr zk cp /tmp/security.json zk:/security.json -z ${ZK_HOST}"

print "Configuring Solr collections"
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /opt/configuration/solr/generated_config/daod_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n main_index -d /opt/configuration/solr/generated_config/main_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n chart_index -d /opt/configuration/solr/generated_config/chart_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n highlight_index -d /opt/configuration/solr/generated_config/highlight_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index1 -d /opt/configuration/solr/generated_config/match_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index2 -d /opt/configuration/solr/generated_config/match_index
runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n vq_index -d /opt/configuration/solr/generated_config/vq_index

print "Running secure Solr containers"
runSolr "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" "${SOLR1_VOLUME_NAME}" "8983" "solr1" "${SOLR1_SECRETS_VOLUME_NAME}"
runSolr "${SOLR2_CONTAINER_NAME}" "${SOLR2_FQDN}" "${SOLR2_VOLUME_NAME}" "8984" "solr2" "${SOLR2_SECRETS_VOLUME_NAME}"
waitForSolrToBeLive "${SOLR1_FQDN}"

###############################################################################
# Restoring non-transient Solr collection                                     #
###############################################################################
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${MAIN_INDEX_BACKUP_NAME}&name=${MAIN_INDEX_BACKUP_NAME}&collection=main_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${MATCH_INDEX_BACKUP_NAME}&name=${MATCH_INDEX_BACKUP_NAME}&collection=match_index1&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=RESTORE&async=${CHART_INDEX_BACKUP_NAME}&name=${CHART_INDEX_BACKUP_NAME}&collection=chart_index&location=${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}\""

###############################################################################
# Monitoring Solr restore process                                             #
###############################################################################
waitForAsynchronousRequestStatusToBeCompleted "${MATCH_INDEX_BACKUP_NAME}"
waitForAsynchronousRequestStatusToBeCompleted "${CHART_INDEX_BACKUP_NAME}"
waitForAsynchronousRequestStatusToBeCompleted "${MAIN_INDEX_BACKUP_NAME}"

###############################################################################
# Recreating transient Solr collections                                       #
###############################################################################
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=daod_index&collection.configName=daod_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=highlight_index&collection.configName=highlight_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index2&collection.configName=match_index2&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=vq_index&collection.configName=vq_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""

###############################################################################
# Restoring system match rules                                                #
###############################################################################
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd makepath /configs/match_index1/match_index1/app
runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd putfile /configs/match_index1/match_index1/app/match-rules.xml "${SOLR_BACKUP_VOLUME_LOCATION}/${backup_version}/system-match-rules.xml"

###############################################################################
# Start Liberty containers                                                    #
###############################################################################
print "Starting Liberty containers"
docker container start "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}"
waitFori2AnalyzeServiceToBeLive
