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

#######################################
# Output in plain text the content of the secret.
# Arguments:
#   The partial path to secret (e.g solr/ZK_DIGEST_PASSWORD)
#######################################
function getSecret() {
  local secret="$1"
  if [[ "${AWS_SECRETS}" == true ]]; then
    aws --output text secretsmanager get-secret-value --secret-id "${secret}" --query SecretString
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

#######################################
# Get Solr component status from a certain point in time.
# Arguments:
#   timestamp
# Outputs:
#   Solr status: Active, Degraded, Down
#######################################
function getSolrStatus() {
  local timestamp="$1"
  local solr_status

  solr_status="$(docker logs --since "${timestamp}" "${LIBERTY1_CONTAINER_NAME}" 2>&1)"
  if grep -q "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'ALL_REPLICAS_ACTIVE'" <<<"${solr_status}"; then
    grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'ALL_REPLICAS_ACTIVE'"  <<<"${solr_status}"

  elif grep -q  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DOWN'" <<<"${solr_status}"; then
    grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DOWN'"  <<<"${solr_status}"

  elif grep -q "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DEGRADED'" <<<"${solr_status}"; then
    grep "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DEGRADED'" <<<"${solr_status}"

  elif grep -q "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'RECOVERING'" <<<"${solr_status}"; then
    grep "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'RECOVERING'" <<<"${solr_status}"

  else
    echo "No response was found from the component availability log (attempt: ${i}). Waiting..."
  fi
}

function getAsyncRequestStatus() {
  local async_id="$1"
  local asynch_response
  local error_response

  asynch_response="$(runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=REQUESTSTATUS&requestid=${async_id}&wt=json\"")"
  if [[ $(echo "${asynch_response}" | jq -r ".status.state") == "completed" ]]; then
    echo "completed" && return 0
  else
    error_response=$(echo "${asynch_response}" | jq -r ".success.*.response")
    echo "${error_response}"
  fi
}

#######################################
# Wait for the index to be build by running an admin request
# against Solr API and checking the index is in the "Ready" state.
# Arguments:
#   The name of the index
#######################################
function waitForIndexesToBeBuilt() {
  local match_index="$1"
  local max_tries=15
  local ready_index
  local index_status_response

  print "Waiting for indexes to be built"
  for i in $(seq 1 "${max_tries}"); do
    index_status_response=$(
      runi2AnalyzeToolAsExternalUser bash -c "curl \
        --silent \
        --cookie-jar /tmp/cookie.txt \
        --cacert /tmp/i2acerts/CA.cer \
        --request POST \"${FRONT_END_URI}/j_security_check\" \
        --header 'Origin: ${FRONT_END_URI}' \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'j_username=Jenny' \
        --data-urlencode 'j_password=Jenny' \
      && curl \
        --silent \
        --cookie /tmp/cookie.txt \
        --cacert /tmp/i2acerts/CA.cer\
        \"${FRONT_END_URI}/api/v1/admin/indexes/status\""
    )
    ready_index=$(echo "${index_status_response}" | jq -r ".match[] | select(.state == \"READY\") | .name")
    if [[ "${ready_index}" == "${match_index}" ]]; then
      echo "${match_index} is ready" && return 0
    fi
    echo "${match_index} is not ready (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForIndexesToBeBuilt has not been succesfull
  printErrorAndExit "${match_index} is NOT ready."
}

#######################################
# Wait for the connector to be live.
# Arguments:
#   Connector fqdn
#   Connector port
#######################################
function waitForConnectorToBeLive() {
  local connector_fqdn="$1"
  local max_tries=50
  local connector_config_url
  if [[ "${GATEWAY_SSL_CONNECTION}" == true ]]; then
    connector_config_url="https://${connector_fqdn}:3700/config"
  else
    connector_config_url="http://${connector_fqdn}:3700/config"
  fi

  print "Waiting for Connector to be live"
  for i in $(seq 1 "${max_tries}"); do
    if [ "$(
      runi2AnalyzeToolAsGatewayUser bash -c "curl --silent --output /dev/null --write-out \"%{http_code}\" \
        --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
    )" ]; then
      http_status_code="$(
        runi2AnalyzeToolAsGatewayUser bash -c "curl --silent --output /dev/null --write-out \"%{http_code}\" \
        --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
      )"
    else
      echo "Curl request to the connector: ${connector_config_url} has failed"
    fi
    if [[ "${http_status_code}" -eq 200 ]]; then
      echo "Connector is live" && return 0
    fi
    echo "Connector is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForConnectorToBeLive has not been succesfull
  runi2AnalyzeToolAsGatewayUser bash -c "curl --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
  printErrorAndExit "Connector is NOT live"
}

###############################################################################
# Database Security Utilities                                                 #
###############################################################################

#######################################
# Change the initial password for the SA user.
# Arguments:
#   None
#######################################
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
# Use an ephemeral SQL Client container to
# create the database logins and users.
# The login and user are created by the `sa` user.
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

#######################################
# Use an ephemeral Solr client container to run commands against Solr.
# Arguments:
#   None
#######################################
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
    -v "${SOLR_BACKUP_VOLUME_NAME}:${SOLR_BACKUP_VOLUME_LOCATION}" \
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

#######################################
# Use an ephemeral Java container to run the i2 Analyze tools.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container to run database scripts or commands
# against the Information Store database as the `etl` user.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container  to run database scripts
# or commands against the Information Store database as the `i2etl` user,
# such as executing generated drop/create index scripts, created by the ETL toolkit.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container to run database scripts or commands
# against the Information Store database as the `sa` user with the initial SA password.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container to run database scripts or commands
# against the Information Store database as the `sa` user.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container to run database scripts or commands
# against the Information Store database as the `dba` user.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral SQL Client container to run database scripts or commands
# against the Information Store database as the `dbb` user.
# Arguments:
#   None
#######################################
function runSQLServerCommandAsDBB() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret sqlserver/dbb_PASSWORD)
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
    -e "DB_USERNAME=${DBB_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}" "$@"
}

#######################################
# Use an ephemeral ETL toolkit container to run ETL toolkit tasks
# against the Information Store using the i2 ETL user credentials.
# Arguments:
#   None
#######################################
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

#######################################
# Use an ephemeral ETL toolkit container to run ETL toolkit tasks
# against the Information Store using the DBA user credentials.
# Arguments:
#   None
#######################################
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

#######################################
# Use the i2 Analyze Tool container to execute any command passed to it,
# but is intended to be used for curl commands against i2Analyze services,
# as it has the required trust and connectivity to do so.
# Arguments:
#   None
#######################################
function runi2AnalyzeToolAsExternalUser() {
  local SSL_CA_CERTIFICATE
  SSL_CA_CERTIFICATE=$(getSecret certificates/externalCA/CA.cer)

  docker run --rm \
    --network "${DOMAIN_NAME}" \
    -e "SERVER_SSL=true" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
}

###############################################################################
# End of function definitions.                                                #
###############################################################################
