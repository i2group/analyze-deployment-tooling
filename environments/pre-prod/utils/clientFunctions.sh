#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

###############################################################################
# Function definitions start here                                             #
###############################################################################

###############################################################################
# Secretes utilities                                                          #
###############################################################################

function getSecret() {
  local secret="${1}"
  if [[ "${AWS_SECRETS}" == true ]]; then
    aws --output text secretsmanager get-secret-value --secret-id "$secret" --query SecretString
  else
    local filePath="${GENERATED_SECRETS_DIR}/${secret}"
    if [[ ! -f "${filePath}" ]]; then
      printErrorAndExit "${filePath} does not exist"
    fi
    cat "${filePath}"
  fi
}

###############################################################################
# Status utilities                                                            #
###############################################################################

function waitForSolrToBeLive() {
  print "Waiting for Solr Node to be live: ${solr_node}"
  local solr_node="${1}"
  local max_tries=15
  for i in $(seq 1 "${max_tries}"); do
    if [[ $(runSolrClientCommand bash -c "curl --write-out \"%{http_code}\" --silent --output /dev/null \
        --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/#/admin/info/health\"") == 200 ]]; then
      jsonResponse=$(
        runSolrClientCommand bash -c "curl --silent -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" \
          --cacert /tmp/i2acerts/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CLUSTERSTATUS\""
      )
      nodes=$(echo "${jsonResponse}" | jq -r '.cluster.live_nodes | join(", ")')
      if grep -q "${solr_node}" <<<"$nodes"; then
        echo "${solr_node} is live" && return 0
      fi
    fi
    echo "${solr_node} is NOT live (attempt: $i). Waiting..."
    sleep 5
  done
  printErrorAndExit "${solr_node} is NOT live. The list of all live nodes: ${nodes}"
}

function waitForSQLServerToBeLive() {
  print "Waiting for Sql Server to be live"
  local MAX_TRIES=15
  local OUTPUT

  for i in $(seq 1 "${MAX_TRIES}"); do
    if runSQLServerCommandAsFirstStartSA bash -c "${SQLCMD} ${SQLCMD_FLAGS} -C -S ${SQL_SERVER_FQDN},${DB_PORT} \
      -U \"\$DB_USERNAME\" -P \"\$DB_PASSWORD\" -Q 'SELECT 1'" >/dev/null; then
      echo "SQL Server is live" && return 0
    fi
    echo "SQL Server is NOT live (attempt: $i). Waiting..."
    sleep 5
  done

  OUTPUT=$(runSQLServerCommandAsFirstStartSA bash -c "${SQLCMD} ${SQLCMD_FLAGS} -C -S ${SQL_SERVER_FQDN},${DB_PORT} \
    -U \"\$DB_USERNAME\" -P \"\$DB_PASSWORD\" -Q 'SELECT 1'")
  printErrorAndExit "SQL Server is NOT live. OUTPUT: ${OUTPUT}"
}

function waitFori2AnalyzeServiceToBeLive() {
  print "Waiting for i2Analyze service to be live"
  local MAX_TRIES=50

  for i in $(seq 1 "${MAX_TRIES}"); do
    http_status_code="$(
      runi2AnalyzeServiceRequest bash -c \
        "echo \"\${SSL_CA_CERTIFICATE}\" >> /tmp/CA.cer && \
        curl \
        --write-out \"%{http_code}\" \
        --silent \
        --output /dev/null  \
        --cacert /tmp/CA.cer \
        \"${FRONT_END_URI}/api/v1/health/live\""
    )"

    if [[ "${http_status_code}" -eq 200 ]]; then
      echo "i2Analyze service is live" && return 0
    fi
    echo "i2Analyze service is NOT live (attempt: $i). Waiting..."
    sleep 10
  done
  printErrorAndExit "i2Analyze service is NOT live"
}

function waitForIndexesToBeBuilt() {
  local MATCH_INDEX="${1}"
  local MAX_TRIES=15
  local READY_INDEX
  local INDEX_STATUS_RESPONSE

  print "Waiting for indexes to be built"
  for i in $(seq 1 "${MAX_TRIES}"); do
    INDEX_STATUS_RESPONSE=$(
      runi2AnalyzeServiceRequest bash -c "echo \"\${SSL_CA_CERTIFICATE}\" >> /tmp/CA.cer && \
      curl \
        --silent \
        --cookie-jar /tmp/cookie.txt \
        --cacert /tmp/CA.cer \
        --request POST \"${FRONT_END_URI}/j_security_check\" \
        --header 'Origin: ${FRONT_END_URI}' \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'j_username=Jenny' \
        --data-urlencode 'j_password=Jenny' \
      && curl \
        --silent \
        --cookie /tmp/cookie.txt \
        --cacert /tmp/CA.cer\
        \"${FRONT_END_URI}/api/v1/admin/indexes/status\""
    )

    READY_INDEX=$(echo "${INDEX_STATUS_RESPONSE}" | jq -r ".match[] | select(.state == \"READY\") | .name")
    if [[ "${READY_INDEX}" == "${MATCH_INDEX}" ]]; then
      echo "${MATCH_INDEX} is built" && return 0
    fi

    echo "${MATCH_INDEX} is not ready. Waiting..."
    sleep 5
  done
  printErrorAndExit "${MATCH_INDEX} is NOT built"
}

function waitForConnectorToBeLive() {
  print "Waiting for Connector to be live"
  local CONNECTOR_FQDN=${1}
  local CONNECTOR_PORT=${2}
  local MAX_TRIES=50
  local CONNECTOR_CONFIG_URL

  if [[ ${GATEWAY_SSL_CONNECTION} == true ]]; then
    CONNECTOR_CONFIG_URL="https://${CONNECTOR_FQDN}:${CONNECTOR_PORT}/config"
  else
    CONNECTOR_CONFIG_URL="http://${CONNECTOR_FQDN}:${CONNECTOR_PORT}/config"
  fi

  for i in $(seq 1 "${MAX_TRIES}"); do
    http_status_code="$(
      runConnectorRequest bash -c \
        "echo \"\${SSL_CA_CERTIFICATE}\" >> /tmp/CA.cer && echo \"\${SSL_PRIVATE_KEY}\" >> /tmp/i2Analyze.pem && echo \"\${SSL_CERTIFICATE}\" >> /tmp/i2Analyze.pem && \
        curl \
        --write-out \"%{http_code}\" \
        --silent \
        --output /dev/null  \
       --cert /tmp/i2Analyze.pem \
       --cacert /tmp/CA.cer \"${CONNECTOR_CONFIG_URL}\""
    )"

    if [[ "${http_status_code}" -eq 200 ]]; then
      echo "Connector is live" && return 0
    fi
    echo "Connector is NOT live (attempt: $i). Waiting..."
    sleep 5
  done
  printErrorAndExit "Connector is NOT live"
}

###############################################################################
# Database Security Utilities                                                 #
###############################################################################

function changeSAPassword() {
  local SA_PASSWORD
  local SA_INITIAL_PASSWORD
  local SSL_CA_CERTIFICATE
  SA_PASSWORD=$(getSecret sqlserver/sa_PASSWORD)
  SA_INITIAL_PASSWORD=$(getSecret sqlserver/sa_INITIAL_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -e "SA_USERNAME=${SA_USERNAME}" \
    -e "SA_OLD_PASSWORD=${SA_INITIAL_PASSWORD}" \
    -e "SA_NEW_PASSWORD=${SA_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    "${SQL_CLIENT_IMAGE_NAME}" \
    "/opt/db-scripts/changeSAPassword.sh"
}

#######################################
# Sets up a user in the database and assigns role
# Arguments:
#   1: The database user name
#   2: The database role name
#######################################
function createDbLoginAndUser() {
  local user="$1"
  local role="$2"
  local SA_PASSWORD
  local USER_PASSWORD
  local SSL_CA_CERTIFICATE
  SA_PASSWORD=$(getSecret sqlserver/sa_PASSWORD)
  USER_PASSWORD=$(getSecret sqlserver/"${user}"_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -e "SA_USERNAME=${SA_USERNAME}" \
    -e "SA_PASSWORD=${SA_PASSWORD}" \
    -e "DB_USERNAME=${user}" \
    -e "DB_PASSWORD=${USER_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_ROLE=${role}" \
    "${SQL_CLIENT_IMAGE_NAME}" \
    "/opt/db-scripts/createDbLoginAndUser.sh"
}

###############################################################################
# Execution Utilities                                                          #
###############################################################################

function runSolrClientCommand() {
  local ZOO_DIGEST_PASSWORD
  local ZOO_DIGEST_READONLY_PASSWORD
  local SOLR_ADMIN_DIGEST_PASSWORD
  local SECURITY_JSON
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE

  ZOO_DIGEST_PASSWORD=$(getSecret solr/ZK_DIGEST_PASSWORD)
  ZOO_DIGEST_READONLY_PASSWORD=$(getSecret solr/ZK_DIGEST_READONLY_PASSWORD)
  SOLR_ADMIN_DIGEST_PASSWORD=$(getSecret solr/SOLR_ADMIN_DIGEST_PASSWORD)
  SECURITY_JSON=$(getSecret solr/security.json)
  SSL_PRIVATE_KEY=$(getSecret certificates/solrClient/server.key)
  SSL_CERTIFICATE=$(getSecret certificates/solrClient/server.cer)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run --rm \
    --net "${DOMAIN_NAME}" \
    --init \
    -v "${LOCAL_CONFIG_DIR}:/opt/configuration" \
    -e SOLR_ADMIN_DIGEST_USERNAME="${SOLR_ADMIN_DIGEST_USERNAME}" \
    -e SOLR_ADMIN_DIGEST_PASSWORD="${SOLR_ADMIN_DIGEST_PASSWORD}" \
    -e ZOO_DIGEST_USERNAME="${ZK_DIGEST_USERNAME}" \
    -e ZOO_DIGEST_PASSWORD="${ZOO_DIGEST_PASSWORD}" \
    -e ZOO_DIGEST_READONLY_USERNAME="${ZK_DIGEST_READONLY_USERNAME}" \
    -e ZOO_DIGEST_READONLY_PASSWORD="${ZOO_DIGEST_READONLY_PASSWORD}" \
    -e SECURITY_JSON="${SECURITY_JSON}" \
    -e SOLR_ZOO_SSL_CONNECTION="${SOLR_ZOO_SSL_CONNECTION}" \
    -e SSL_PRIVATE_KEY="${SSL_PRIVATE_KEY}" \
    -e SSL_CERTIFICATE="${SSL_CERTIFICATE}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${SOLR_IMAGE_NAME}" "$@"
}

function runi2AnalyzeTool() {
  local ZOO_DIGEST_PASSWORD
  local ZOO_DIGEST_READONLY_PASSWORD
  local SOLR_ADMIN_DIGEST_PASSWORD
  local DBA_PASSWORD
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE
  ZOO_DIGEST_PASSWORD=$(getSecret solr/ZK_DIGEST_PASSWORD)
  ZOO_DIGEST_READONLY_PASSWORD=$(getSecret solr/ZK_DIGEST_READONLY_PASSWORD)
  SOLR_ADMIN_DIGEST_PASSWORD=$(getSecret solr/SOLR_ADMIN_DIGEST_PASSWORD)
  DBA_PASSWORD=$(getSecret sqlserver/dba_PASSWORD)
  SSL_PRIVATE_KEY=$(getSecret certificates/solrClient/server.key)
  SSL_CERTIFICATE=$(getSecret certificates/solrClient/server.cer)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${I2A_TOOL_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --user "$(id -u "${USER}"):$(id -u "${USER}")" \
    -v "${LOCAL_CONFIG_DIR}:/opt/configuration" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "LIC_AGREEMENT=${LIC_AGREEMENT}" \
    -e ZK_HOST="${ZK_MEMBERS}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "CONFIG_DIR=/opt/configuration" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DBA_USERNAME}" \
    -e "DB_PASSWORD=${DBA_PASSWORD}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e SOLR_ADMIN_DIGEST_USERNAME="${SOLR_ADMIN_DIGEST_USERNAME}" \
    -e SOLR_ADMIN_DIGEST_PASSWORD="${SOLR_ADMIN_DIGEST_PASSWORD}" \
    -e ZOO_DIGEST_USERNAME="${ZK_DIGEST_USERNAME}" \
    -e ZOO_DIGEST_PASSWORD="${ZOO_DIGEST_PASSWORD}" \
    -e ZOO_DIGEST_READONLY_USERNAME="${ZK_DIGEST_READONLY_USERNAME}" \
    -e ZOO_DIGEST_READONLY_PASSWORD="${ZOO_DIGEST_READONLY_PASSWORD}" \
    -e DB_SSL_CONNECTION="${DB_SSL_CONNECTION}" \
    -e SOLR_ZOO_SSL_CONNECTION="${SOLR_ZOO_SSL_CONNECTION}" \
    -e SSL_PRIVATE_KEY="${SSL_PRIVATE_KEY}" \
    -e SSL_CERTIFICATE="${SSL_CERTIFICATE}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
}

function runSQLServerCommandAsETL() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/etl_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${ETL_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

function runSQLServerCommandAsi2ETL() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/i2etl_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -v "${LOCAL_TOOLKIT_DIR}:/opt/toolkit" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${I2_ETL_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

function runSQLServerCommandAsFirstStartSA() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/sa_INITIAL_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${SA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

function runSQLServerCommandAsSA() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/sa_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${SA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

function runSQLServerCommandAsDBA() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/dba_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DBA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

function runEtlToolkitToolAsi2ETL() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/i2etl_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${ETL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --user "$(id -u "${USER}"):$(id -u "${USER}")" \
    -v "${LOCAL_CONFIG_DIR}/logs:/opt/configuration/logs" \
    -v "${LOCAL_TOOLKIT_DIR}/examples/data:/tmp/examples/data" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "JAVA_HOME=/opt/java/openjdk/bin/java" \
    -e "DB_USERNAME=${I2_ETL_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${ETL_CLIENT_IMAGE_NAME}" "$@"
}

function runEtlToolkitToolAsDBA() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/dba_PASSWORD)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run \
    --rm \
    --name "${ETL_CLIENT_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --user "$(id -u "${USER}"):$(id -u "${USER}")" \
    -v "${LOCAL_CONFIG_DIR}/logs:/opt/configuration/logs" \
    -v "${LOCAL_TOOLKIT_DIR}/examples/data:/tmp/examples/data" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "JAVA_HOME=/opt/java/openjdk/bin/java" \
    -e "DB_USERNAME=${DBA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${ETL_CLIENT_IMAGE_NAME}" "$@"
}

function runi2AnalyzeServiceRequest() {
  local SSL_CA_CERTIFICATE
  SSL_CA_CERTIFICATE=$(getSecret certificates/externalCA/CA.cer)

  docker run --rm \
    --network "${DOMAIN_NAME}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
}

function runConnectorRequest() {
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE
  SSL_PRIVATE_KEY=$(getSecret certificates/gateway_user/server.key)
  SSL_CERTIFICATE=$(getSecret certificates/gateway_user/server.cer)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run --rm \
    --network "${DOMAIN_NAME}" \
    -e SSL_PRIVATE_KEY="${SSL_PRIVATE_KEY}" \
    -e SSL_CERTIFICATE="${SSL_CERTIFICATE}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
}
###############################################################################
# End of function definitions.                                                #
###############################################################################
