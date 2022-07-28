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

setDependenciesTagIfNecessary
checkEnvironmentIsValid
checkClientFunctionsEnvironmentVariablesAreSet
checkLicensesAcceptedIfRequired "${ENVIRONMENT}"

###############################################################################
# Functions                                                                   #
###############################################################################

function deployZKCluster() {
  runZK "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" "${ZK1_DATA_VOLUME_NAME}" "${ZK1_DATALOG_VOLUME_NAME}" "${ZK1_LOG_VOLUME_NAME}" "1" "zk1" "${ZK1_SECRETS_VOLUME_NAME}"
  runZK "${ZK2_CONTAINER_NAME}" "${ZK2_FQDN}" "${ZK2_DATA_VOLUME_NAME}" "${ZK2_DATALOG_VOLUME_NAME}" "${ZK2_LOG_VOLUME_NAME}" "2" "zk2" "${ZK2_SECRETS_VOLUME_NAME}"
  runZK "${ZK3_CONTAINER_NAME}" "${ZK3_FQDN}" "${ZK3_DATA_VOLUME_NAME}" "${ZK3_DATALOG_VOLUME_NAME}" "${ZK3_LOG_VOLUME_NAME}" "3" "zk3" "${ZK3_SECRETS_VOLUME_NAME}"
}

function deploySolrCluster() {
  print "Running secure Solr containers"
  ### Run solr1
  runSolr "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" "${SOLR1_VOLUME_NAME}" "8983" "solr1" "${SOLR1_SECRETS_VOLUME_NAME}"
  ### Run solr2
  runSolr "${SOLR2_CONTAINER_NAME}" "${SOLR2_FQDN}" "${SOLR2_VOLUME_NAME}" "8984" "solr2" "${SOLR2_SECRETS_VOLUME_NAME}"
}

function configureZKForSolrCluster() {
  print "Configuring ZK Cluster for Solr"
  runSolrClientCommand solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == true ]]; then
    runSolrClientCommand "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
  fi
  runSolrClientCommand bash -c "echo \"\${SECURITY_JSON}\" > /tmp/security.json && solr zk cp /tmp/security.json zk:/security.json -z ${ZK_HOST}"
}

function configureSolrCollections() {
  print "Configuring Solr collections"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateSolrSchemas.sh"
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /opt/configuration/solr/generated_config/daod_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n main_index -d /opt/configuration/solr/generated_config/main_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n chart_index -d /opt/configuration/solr/generated_config/chart_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n highlight_index -d /opt/configuration/solr/generated_config/highlight_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index1 -d /opt/configuration/solr/generated_config/match_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index2 -d /opt/configuration/solr/generated_config/match_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n vq_index -d /opt/configuration/solr/generated_config/vq_index
}

function createSolrClusterPolicy() {
  print "Creating Solr cluster policy"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer -X POST -H Content-Type:text/xml -d '{ \"set-cluster-policy\": [ {\"replica\": \"<2\", \"shard\": \"#EACH\", \"host\": \"#EACH\"}]}' \"${SOLR1_BASE_URL}/api/cluster/autoscaling\""
}

function createSolrCollections() {
  print "Creating Solr collections"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=main_index&collection.configName=main_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index1&collection.configName=match_index1&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index2&collection.configName=match_index2&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=chart_index&collection.configName=chart_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=daod_index&collection.configName=daod_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=highlight_index&collection.configName=highlight_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=vq_index&collection.configName=vq_index&numShards=1&maxShardsPerNode=4&replicationFactor=2\""
}

function initializeIStoreDatabase() {
  print "Setting up IStore database security"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateInfoStoreToolScripts.sh"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateStaticInfoStoreCreationScripts.sh"
  runSQLServerCommandAsSA "/opt/databaseScripts/generated/runDatabaseCreationScripts.sh"

  print "Creating database roles"
  runSQLServerCommandAsSA "/opt/db-scripts/createDbRoles.sh"

  print "Creating database logins and users"
  createDbLoginAndUser "dbb" "db_backupoperator"
  createDbLoginAndUser "dba" "DBA_Role"
  createDbLoginAndUser "i2analyze" "i2Analyze_Role"
  createDbLoginAndUser "i2etl" "i2_ETL_Role"
  createDbLoginAndUser "etl" "External_ETL_Role"
  runSQLServerCommandAsSA "/opt/db-scripts/configureDbaRolesAndPermissions.sh"
  runSQLServerCommandAsSA "/opt/db-scripts/addEtlUserToSysAdminRole.sh"

  print "Initializing IStore database tables"
  runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runStaticScripts.sh"
}

function deploySecureSQLServer() {
  docker volume create "${SQL_SERVER_BACKUP_VOLUME_NAME}"
  runSQLServer
  waitForSQLServerToBeLive "true"
  changeSAPassword
}

function configureIStoreDatabase() {
  print "Configuring IStore database"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateDynamicInfoStoreCreationScripts.sh"
  runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runDynamicScripts.sh"
}

function deployLiberty() {
  ### Run liberty1
  runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_SECRETS_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_DEBUG_PORT}"
  ### Run liberty2
  runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_SECRETS_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_DEBUG_PORT}"
  ### Run load_balancer
  runLoadBalancer
}

function configureI2Analyze() {
  print "Configuring the i2Analyze application server in HA mode"
  buildLibertyConfiguredImageForPreProd
  deployLiberty
  waitFori2AnalyzeServiceToBeLive

  ### Upload match rules
  print "Uploading system match rules"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" update_match_rules

  ### Wait for indexes to be built
  waitForIndexesToBeBuilt "match_index1"

  ### Switch standby match index to live
  print "Switching standby match index to live"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live
}

function configureExampleConnector() {
  runExampleConnector "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_FQDN}" "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_SECRETS_VOLUME_NAME}"
  waitForConnectorToBeLive "${CONNECTOR1_FQDN}"
}

function createDataSourceId() {
  local dsid_properties_file_path="${LOCAL_CONFIG_DIR}/environment/dsid/dsid.infostore.properties"

  createDsidPropertiesFile "${dsid_properties_file_path}"
}

EXTENSIONS_DEV="true"
###############################################################################
# Cleaning up Docker resources                                                #
###############################################################################
cleanUpDockerResources

###############################################################################
# Creating Docker network                                                     #
###############################################################################
createDockerNetwork "${DOMAIN_NAME}"

###############################################################################
# Create dsid.infostore.properties file                                       #
###############################################################################
createDataSourceId

###############################################################################
# Running Solr and ZooKeeper                                                  #
###############################################################################
deployZKCluster
configureZKForSolrCluster
deploySolrCluster

###############################################################################
# Initializing the Information Store database                                 #
###############################################################################
deploySecureSQLServer
initializeIStoreDatabase

###############################################################################
# Configuring Solr and ZooKeeper                                              #
###############################################################################
waitForSolrToBeLive "${SOLR1_FQDN}"
configureSolrCollections
createSolrClusterPolicy
createSolrCollections

###############################################################################
# Configuring Information Store database                                      #
###############################################################################
configureIStoreDatabase

###############################################################################
# Configuring Example Connector                                               #
###############################################################################
configureExampleConnector

###############################################################################
# Configuring i2 Analyze                                                      #
###############################################################################
configureI2Analyze

###############################################################################
# Run Prometheus and Grafana                                                  #
###############################################################################
configurePrometheusForPreProd
runPrometheus
waitForPrometheusServerToBeLive

runGrafana
waitForGrafanaServerToBeLive

set +e
