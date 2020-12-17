#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"

# Loading common variables and functions
source ./utils/commonFunctions.sh
source ./utils/serverFunctions.sh
source ./utils/clientFunctions.sh
source ./utils/commonVariables.sh

###############################################################################
# AWS Utils                                                                   #
###############################################################################
check_status() {
  max_tries="$1"
  test_command="$2"
  required_value="$3"
  error="$4"

  ok="false"
  for i in $(seq 1 "$max_tries"); do
    return_value=$(eval "${test_command}")
    if [ "$return_value" == "$required_value" ]; then
      ok="true"
      break
    else
      echo -n "."
    fi
    sleep 5
  done
  if [ "$ok" == "false" ]; then
    printf "\n\e[31mERROR:\e[0m %s\n" "${error}"
    exit 1
  fi
}

waitForAWSService() {
  service=$1
  echo "Waiting for service to become available"
  service_status="aws ecs describe-services --cluster i2a-stack-ECSCluster --services ${service} --query 'services[0].deployments[0].runningCount' --output text"
  msg="Service failed to start- giving up"
  check_status "50" "$service_status" "1" "$msg"
}

###############################################################################
# Functions                                                                   #
###############################################################################

function deployZKCluster() {
  if [[ "${AWS_DEPLOY}" == true ]]; then
    aws ecs update-service --cluster i2a-stack-ECSCluster --service zk1 --desired-count 1 --force-new-deployment
    waitForAWSService zk1
  else
    runZK "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" "${ZK1_DATA_VOLUME_NAME}" "${ZK1_DATALOG_VOLUME_NAME}" "${ZK1_LOG_VOLUME_NAME}" "8080" "1"
    runZK "${ZK2_CONTAINER_NAME}" "${ZK2_FQDN}" "${ZK2_DATA_VOLUME_NAME}" "${ZK2_DATALOG_VOLUME_NAME}" "${ZK2_LOG_VOLUME_NAME}" "8081" "2"
    runZK "${ZK3_CONTAINER_NAME}" "${ZK3_FQDN}" "${ZK3_DATA_VOLUME_NAME}" "${ZK3_DATALOG_VOLUME_NAME}" "${ZK3_LOG_VOLUME_NAME}" "8082" "3"
  fi
}

function deploySolrCluster() {
  if [[ "${AWS_DEPLOY}" == true ]]; then
    aws ecs update-service --cluster i2a-stack-ECSCluster --service solr1 --desired-count 1 --force-new-deployment
    aws ecs update-service --cluster i2a-stack-ECSCluster --service solr2 --desired-count 1 --force-new-deployment
    waitForAWSService solr1
    waitForAWSService solr2
  else
    print "Running secure Solr containers"
    ### Run solr1
    runSolr "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" "${SOLR1_VOLUME_NAME}" "8983"
    ### Run solr2
    runSolr "${SOLR2_CONTAINER_NAME}" "${SOLR2_FQDN}" "${SOLR2_VOLUME_NAME}" "8984"
  fi
}

function configureZKForSolrCluster() {
  print "Configuring ZK Cluster for Solr"
  runSolrClientCommand solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == true ]]; then
    runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
  fi
  runSolrClientCommand bash -c "echo \"\${SECURITY_JSON}\" > /tmp/security.json && solr zk cp /tmp/security.json zk:/security.json -z ${ZK_HOST}"
}

function configureSolrCollections() {
  print "Configuring Solr collections"
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /opt/configuration/solr/daod_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n main_index -d /opt/configuration/solr/main_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n chart_index -d /opt/configuration/solr/chart_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n highlight_index -d /opt/configuration/solr/highlight_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index1 -d /opt/configuration/solr/match_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index2 -d /opt/configuration/solr/match_index
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
}

function initializeIStoreDatabase() {
  print "Setting up IStore database security"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateInfoStoreToolScripts.sh"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateStaticInfoStoreCreationScripts.sh"
  runSQLServerCommandAsSA "/opt/databaseScripts/generated/runDatabaseCreationScripts.sh"

  print "Creating database roles"
  runSQLServerCommandAsSA "/opt/db-scripts/createDbRoles.sh"

  print "Creating database logins and users"
  createDbLoginAndUser "dba" "DBA_Role"
  runSQLServerCommandAsSA "/opt/db-scripts/grantDBAServerStatePermissions.sh"
  createDbLoginAndUser "i2analyze" "i2Analyze_Role"
  createDbLoginAndUser "i2etl" "i2_ETL_Role"
  createDbLoginAndUser "etl" "External_ETL_Role"
  runSQLServerCommandAsSA "/opt/db-scripts/addEtlUserToSysAdminRole.sh"

  print "Initializing IStore database tables"
  runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runStaticScripts.sh"
}

function deploySecureSQLServer() {
  if [[ "${AWS_DEPLOY}" == true ]]; then
    aws ecs update-service --cluster i2a-stack-ECSCluster --service sqlserver --desired-count 1 --force-new-deployment
    waitForAWSService sqlserver
  else
    runSQLServer
    waitForSQLServerToBeLive
  fi
  changeSAPassword
}

function configureIStoreDatabase() {
  print "Configuring IStore database"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateDynamicInfoStoreCreationScripts.sh"
  runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runDynamicScripts.sh"
}

function deployLiberty() {
  if [[ "${AWS_DEPLOY}" == true ]]; then
    aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin "${ECR_BASE_NAME}"
    docker push "${LIBERTY_CONFIGURED_IMAGE_NAME}":latest
    aws ecs update-service --cluster i2a-stack-ECSCluster --service i2analyze --desired-count 1 --force-new-deployment
    waitForAWSService i2analyze
  else
    # Run liberty1
    runLiberty "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${LIBERTY1_PORT}" "${LIBERTY1_CONTAINER_NAME}"
    # Run liberty2
    runLiberty "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" "${LIBERTY2_VOLUME_NAME}" "${LIBERTY2_PORT}" "${LIBERTY2_CONTAINER_NAME}"
    # Run load_balancer
    runLoadBalancer
  fi
}

function configureI2Analyze() {
  print "Configuring the i2Analyze application server in HA mode"
  buildLibertyConfiguredImage
  deployLiberty
  waitFori2AnalyzeServiceToBeLive

  ### Configure i2Analyze
  print "Uploading system match rules"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" update_match_rules

  waitForIndexesToBeBuilt "match_index1"

  print "Switching standby match index to live"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live
}

function configureExampleConnector() {
  runExampleConnector "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_FQDN}" "${CONNECTOR1_PORT}"
  waitForConnectorToBeLive "${CONNECTOR1_FQDN}" "${CONNECTOR1_PORT}"
}

###############################################################################
# Cleaning up Docker resources                                                #
###############################################################################
removeAllContainersAndNetwork
removeDockerVolumes

###############################################################################
# Creating Docker network                                                     #
###############################################################################
print "Creating docker network: ${DOMAIN_NAME}"
docker network create "${DOMAIN_NAME}"

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

set +e
