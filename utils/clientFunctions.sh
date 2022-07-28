#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

###############################################################################
# Function definitions start here                                             #
###############################################################################

###############################################################################
# Secretes utilities                                                          #
###############################################################################

#######################################
# Check if all required environment variables are set.
# Arguments:
#   None
#######################################
function checkClientFunctionsEnvironmentVariablesAreSet() {
  while read -r var_name; do
    checkVariableIsSet "${!var_name}" "${var_name} environment variable is not set"
  done <"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/requiredEnvironmentVariables.txt"
}

function isSecret() {
  local secret="$1"
  aws secretsmanager describe-secret --secret-id "${DEPLOYMENT_NAME}/${secret}" --region "${AWS_REGION}" >/dev/null
}

#######################################
# Output in plain text the content of the secret.
# Arguments:
#   The partial path to secret (e.g solr/ZK_DIGEST_PASSWORD)
#######################################
function getSecret() {
  local secret="$1"
  if [[ "${AWS_SECRETS}" == true ]]; then
    aws --output text secretsmanager get-secret-value --secret-id "${DEPLOYMENT_NAME}/${secret}" --query SecretString --region "${AWS_REGION}"
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
    grep "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'ALL_REPLICAS_ACTIVE'" <<<"${solr_status}"

  elif grep -q "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DOWN'" <<<"${solr_status}"; then
    grep "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DOWN'" <<<"${solr_status}"

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
  local async_response
  local error_response

  async_response="$(runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=REQUESTSTATUS&requestid=${async_id}&wt=json\"")"
  if [[ $(echo "${async_response}" | jq -r ".status.state") == "completed" ]]; then
    echo "completed" && return 0
  else
    error_response=$(echo "${async_response}" | jq -r ".success.*.response")
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
  local app_admin_password

  app_admin_password=$(getApplicationAdminPassword)
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
        --data-urlencode 'j_username=${I2_ANALYZE_ADMIN}' \
        --data-urlencode 'j_password=${app_admin_password}' \
      && curl \
        --silent \
        --cookie /tmp/cookie.txt \
        --cacert /tmp/i2acerts/CA.cer\
        \"${FRONT_END_URI}/api/v1/admin/indexes/status\""
    )
    ready_index=$(echo "${index_status_response}" | jq -r ".status.match[] | select(.state == \"READY\") | .name")
    if [[ "${ready_index}" == "${match_index}" ]]; then
      echo "${match_index} is ready" && return 0
    fi
    echo "${match_index} is not ready (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForIndexesToBeBuilt has not been successful
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
  local configuration_path="${2:-/config}"
  local max_tries=10
  local connector_config_url

  if [[ "${GATEWAY_SSL_CONNECTION}" == true ]]; then
    connector_config_url="https://${connector_fqdn}:3443${configuration_path}"
  else
    connector_config_url="http://${connector_fqdn}:3443${configuration_path}"
  fi

  print "Waiting for Connector to be live on ${connector_config_url}"

  for i in $(seq 1 "${max_tries}"); do
    if runi2AnalyzeToolAsGatewayUser bash -c "curl -s -S --output /dev/null \
        --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""; then
      http_status_code="$(
        runi2AnalyzeToolAsGatewayUser bash -c "curl -s --output /dev/null --write-out \"%{http_code}\" \
        --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
      )"
      if [[ "${http_status_code}" -eq 200 ]]; then
        echo "Connector is live" && return 0
      else
        echo "Incorrect status code returned from connector:${http_status_code}"
      fi
    fi
    echo "Could not connect to ${connector_config_url}"
    echo "Connector is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForConnectorToBeLive has not been successful. Run curl with -v
  runi2AnalyzeToolAsGatewayUser bash -c "curl -v --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
  printWarn "Connector is NOT live at ${connector_config_url}"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  # shellcheck disable=SC2153
  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -e "SA_USERNAME=${SA_USERNAME}" \
    -e "SA_OLD_PASSWORD=${SA_INITIAL_PASSWORD}" \
    -e "SA_NEW_PASSWORD=${SA_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" \
    "/opt/db-scripts/changeSAPassword.sh"
}

#######################################
# Change the initial password for the db2inst1 user.
# Arguments:
#   None
#######################################
function changeDb2inst1Password() {
  local DB2INST1_PASSWORD
  local DB2INST1_INITIAL_PASSWORD
  local SSL_CA_CERTIFICATE
  DB2INST1_PASSWORD=$(getSecret db2server/db2inst1_PASSWORD)
  DB2INST1_INITIAL_PASSWORD=$(getSecret db2server/db2inst1_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  # shellcheck disable=SC2153
  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${DB2_CLIENT_CONTAINER_NAME}" \
    --privileged=true \
    -e "SQLCMD=${SQLCMD}" \
    -e "DB2INST1_USERNAME=${DB2INST1_USERNAME}" \
    -e "DB2INST1_OLD_PASSWORD=${DB2INST1_INITIAL_PASSWORD}" \
    -e "DB2INST1_NEW_PASSWORD=${DB2INST1_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    -e "DB_SERVER=${DB2_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NODE=${DB_NODE}" \
    "${DB2_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" \
    "/opt/db-scripts/changeDb2inst1Password.sh"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
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
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" \
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

  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
    SSL_PRIVATE_KEY=$(getSecret certificates/solrClient/server.key)
    SSL_CERTIFICATE=$(getSecret certificates/solrClient/server.cer)
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
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
    "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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
  local DB_SERVER_FQDN
  local DB_USERNAME
  local DB_PASSWORD
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE
  ZOO_DIGEST_PASSWORD=$(getSecret solr/ZK_DIGEST_PASSWORD)
  ZOO_DIGEST_READONLY_PASSWORD=$(getSecret solr/ZK_DIGEST_READONLY_PASSWORD)
  SOLR_ADMIN_DIGEST_PASSWORD=$(getSecret solr/SOLR_ADMIN_DIGEST_PASSWORD)

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(getSecret db2server/db2inst1_PASSWORD)
    DB_SERVER_FQDN="${DB2_SERVER_FQDN}"
    ;;
  sqlserver)
    # shellcheck disable=SC2153
    DB_USERNAME="${DBA_USERNAME}"
    DB_PASSWORD=$(getSecret sqlserver/dba_PASSWORD)
    DB_SERVER_FQDN="${SQL_SERVER_FQDN}"
    ;;
  esac

  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
    SSL_PRIVATE_KEY=$(getSecret certificates/solrClient/server.key)
    SSL_CERTIFICATE=$(getSecret certificates/solrClient/server.cer)
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${I2A_TOOL_CONTAINER_NAME}" \
    -v "${LOCAL_CONFIG_DIR}:/opt/configuration" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "LIC_AGREEMENT=${LIC_AGREEMENT}" \
    -e ZK_HOST="${ZK_MEMBERS}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_SERVER=${DB_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "CONFIG_DIR=/opt/configuration" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DB_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "DB_CREATE_DATABASE=false" \
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
    "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${ETL_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_TOOLKIT_DIR}:/opt/toolkit" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${I2_ETL_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${SA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${SA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DBA_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  # shellcheck disable=SC2153
  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${SQL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DBB_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Use an ephemeral ETL toolkit container to run ETL toolkit tasks
# against the Information Store using the i2 ETL user credentials.
# Arguments:
#   None
#######################################
function runEtlToolkitToolAsi2ETL() {
  local DB_USERNAME
  local DB_PASSWORD
  local DB_SERVER_FQDN
  local SSL_CA_CERTIFICATE

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(getSecret db2server/db2inst1_PASSWORD)
    DB_SERVER_FQDN="${DB2_SERVER_FQDN}"
    ;;
  sqlserver)
    DB_USERNAME="${I2_ETL_USERNAME}"
    DB_PASSWORD=$(getSecret sqlserver/i2etl_PASSWORD)
    DB_SERVER_FQDN="${SQL_SERVER_FQDN}"
    ;;
  esac

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_CLIENT_VOLUME_NAME}" "${container_data_dir}"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${ETL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_CONFIG_DIR}/logs:/opt/configuration/logs" \
    -v "${I2A_DATA_CLIENT_VOLUME_NAME}:${container_data_dir}" \
    -e "DB_SERVER=${DB_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "ETL_TOOLKIT_JAVA_HOME=/opt/java/openjdk/bin" \
    -e "DB_USERNAME=${DB_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${ETL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Use an ephemeral ETL toolkit container to run ETL toolkit tasks
# against the Information Store using the DBA user credentials.
# Arguments:
#   None
#######################################
function runEtlToolkitToolAsDBA() {
  local DB_USERNAME
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(getSecret db2server/db2inst1_PASSWORD)
    ;;
  sqlserver)
    DB_USERNAME="${DBA_USERNAME}"
    DB_PASSWORD=$(getSecret sqlserver/dba_PASSWORD)
    ;;
  esac

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_CLIENT_VOLUME_NAME}" "${container_data_dir}"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${ETL_CLIENT_CONTAINER_NAME}" \
    -v "${LOCAL_CONFIG_DIR}/logs:/opt/configuration/logs" \
    -v "${I2A_DATA_CLIENT_VOLUME_NAME}:${container_data_dir}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_OS_TYPE=${DB_OS_TYPE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "ETL_TOOLKIT_JAVA_HOME=/opt/java/openjdk/bin" \
    -e "DB_USERNAME=${DB_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${ETL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Use an ephemeral Db2 Client container to run database scripts or commands
# against the Information Store database as the `db2inst1` user.
# Arguments:
#   None
#######################################
function runDb2ServerCommandAsDb2inst1() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret db2server/db2inst1_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${DB2_CLIENT_CONTAINER_NAME}" \
    --privileged=true \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -v "${LOCAL_CONFIG_DIR}:/opt/configuration" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_LOCATION_DIR=${DB_LOCATION_DIR}" \
    -e "DB_SERVER=${DB2_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_NODE=${DB_NODE}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DB2INST1_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${DB2_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Use an ephemeral Db2 Client container to run database scripts or commands
# against the Information Store database as the `db2inst1` user with the initial db2inst1 password.
# Arguments:
#   None
#######################################
function runDb2ServerCommandAsAsFirstStartDb2inst1() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(getSecret db2server/db2inst1_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)
  fi

  docker run \
    --rm \
    "${EXTRA_ARGS[@]}" \
    --name "${DB2_CLIENT_CONTAINER_NAME}" \
    --privileged=true \
    -v "${LOCAL_GENERATED_DIR}:/opt/databaseScripts/generated" \
    -e "SQLCMD=${SQLCMD}" \
    -e "SQLCMD_FLAGS=${SQLCMD_FLAGS}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB_SERVER=${DB2_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_NAME=${DB_NAME}" \
    -e "DB_NODE=${DB_NODE}" \
    -e "GENERATED_DIR=/opt/databaseScripts/generated" \
    -e "DB_USERNAME=${DB2INST1_USERNAME}" \
    -e "DB_PASSWORD=${DB_PASSWORD}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${DB2_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
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
    "${EXTRA_ARGS[@]}" \
    -e "SERVER_SSL=true" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Use this function to update the named volume
# with the content of your local directory.
# e.g. updateVolume "${LOCAL_KEYS_DIR}" "${SECRETS_VOLUME_NAME}" "/run/secrets"
# Arguments:
#   1. Directory local on your machine.
#   2. Volume name.
#   3. Directory inside the volume.
#######################################
function updateVolume() {
  local local_dir="$1"
  local volume_name="$2"
  local volume_dir="$3"

  docker run \
    --rm \
    -v "${local_dir}:/run/bind-mount" \
    -v "${volume_name}:${volume_dir}" \
    "${REDHAT_UBI_IMAGE_NAME}" \
    bash -c "rm -rf ${volume_dir}/* && cp -r '/run/bind-mount/.' '${volume_dir}'"
}

#######################################
# Use this function to get the content of the named volume
# in your local directory.
# e.g. getVolume "${LOCAL_KEYS_DIR}" "${SECRETS_VOLUME_NAME}" "/run/secrets"
# Arguments:
#   1. Directory local on your machine.
#   2. Volume name.
#   3. Directory inside the volume.
#######################################
function getVolume() {
  local local_dir="$1"
  local volume_name="$2"
  local volume_dir="$3"

  deleteFolderIfExistsAndCreate "${local_dir}"

  docker run \
    --rm \
    -v "${local_dir}:/run/bind-mount" \
    -v "${volume_name}:${volume_dir}" \
    "${REDHAT_UBI_IMAGE_NAME}" \
    bash -c "cp -r '${volume_dir}/.' /run/bind-mount && chown -R $(id -u "${USER}"):$(id -g "${USER}") /run/bind-mount"
}

function updateGrafanaDashboardVolume() {
  local grafana_dashboards_dir="/etc/grafana/dashboards"
  updateVolume "${LOCAL_GRAFANA_CONFIG_DIR}/dashboards" "${GRAFANA_DASHBOARDS_VOLUME_NAME}" "${grafana_dashboards_dir}"
}

###############################################################################
# End of function definitions.                                                #
###############################################################################
