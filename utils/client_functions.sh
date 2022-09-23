#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

# @file client_functions.sh
# @brief A set of client functions that you can use to perform actions against the server components of i2 Analyze.
# @description
#     The list of client functions groups:
#      * [Environment Utilities](#environment-utilities)
#      * [Secret Utilities](#secret-utilities)
#      * [Status Utilities](#status-utilities)
#      * [Database Security Utilities](#database-security-utilities)
#      * [Execution Utilities](#execution-utilities)
#      * [Volume Utilities](#volume-utilities)

# @section Environment utilities
# @description

# @description Checks if all required environment variables are set.
# @noargs
function check_env_vars_are_set() {
  while read -r var_name; do
    checkVariableIsSet "${!var_name}" "${var_name} environment variable is not set"
  done <"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/requiredEnvironmentVariables.txt"
}

# @section Secret utilities
# @description

# @description Check if the secret name exists in the secret store.
# @arg $1 string The partial path to secret
# @internal
function is_secret() {
  validateParameters "1" "$@"

  local secret="$1"

  aws secretsmanager describe-secret --secret-id "${DEPLOYMENT_NAME}/${secret}" --region "${AWS_REGION}" >/dev/null
}

# @description Gets a secret such as a password for a user.
# @arg $1 string The partial path to secret
# @example
#   get_secret "solr/ZK_DIGEST_PASSWORD"
function get_secret() {
  validateParameters "1" "$@"

  local secret="$1"
  local filePath="${GENERATED_SECRETS_DIR}/${secret}"
  if [[ ! -f "${filePath}" ]]; then
    print_error_and_exit "${filePath} does not exist"
  fi
  cat "${filePath}"
}

# @section Status utilities
# @description

# @description Get Solr component status from a certain point in time.
#
# @example
#    status_message="$(get_solr_status "${SINCE_TIMESTAMP}")"
#
# @arg $1 string "since" timestamp for docker logs commands
#
# @stdout The status of the Solr component.
function get_solr_status() {
  validateParameters "1" "$@"

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

# @description Takes a request to the Asynchronous Collection API and check the state is marked as completed
# in the JSON response returned.
# If the state is not marked as completed, the function returns the response message which contains
# any error messages that are reported with the asynchronous request.
# For more information about the Asynchronous Collection API, see [REQUESTSTATUS: Request Status of an Async Call](https://lucene.apache.org/solr/guide/8_7/collections-api.html#requeststatus).
# @arg $1 string The request id of the asynchronous request to get the status of.
# @stdout The JSON response or error messages.
function get_async_request_status() {
  validateParameters "1" "$@"

  local async_id="$1"
  local async_response
  local error_response

  async_response="$(run_solr_client_command bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=REQUESTSTATUS&requestid=${async_id}&wt=json\"")"
  if [[ $(echo "${async_response}" | jq -r ".status.state") == "completed" ]]; then
    echo "completed" && return 0
  else
    error_response=$(echo "${async_response}" | jq -r ".success.*.response")
    echo "${error_response}"
  fi
}

# @description Wait for the index to be build by running an admin request
# against Solr API and checking the index is in the "Ready" state.
#
# @example
#    wait_for_indexes_to_be_built "match_index1"
#
# @arg $1 string Index Name
#
# @exitcode 0 If index was built in 75 seconds.
# @exitcode 1 If index was NOT built in 75 seconds.
function wait_for_indexes_to_be_built() {
  validateParameters "1" "$@"

  local match_index="$1"
  local max_tries=15
  local ready_index
  local index_status_response
  local app_admin_password

  app_admin_password=$(getApplicationAdminPassword)
  print "Waiting for indexes to be built"
  for i in $(seq 1 "${max_tries}"); do
    index_status_response=$(
      run_i2_analyze_tool_as_external_user bash -c "curl \
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

  # If you get here, wait_for_indexes_to_be_built has not been successful
  print_error_and_exit "${match_index} is NOT ready."
}

# @description Sends a request to the connector's/config endpoint.
# If the response is 200, the connector is live.
# If the connector is not live after 10 retries the function will print an error and exit.
# @arg $1 string The fully qualified domain name of a connector
# @arg $2 string The configuration path of the connector
# @exitcode 0 If the connector is live.
# @exitcode 1 If the connector is not live after 10 retries.
# @stdout Retry attempts, error messages or success message.
function wait_for_connector_to_be_live() {
  validateParameters "1" "$@"

  local connector_fqdn="$1"
  local connector_config_path="${2:-/config}"
  local max_tries=10
  local connector_config_url

  if [[ "${GATEWAY_SSL_CONNECTION}" == true ]]; then
    connector_config_url="https://${connector_fqdn}:3443${connector_config_path}"
  else
    connector_config_url="http://${connector_fqdn}:3443${connector_config_path}"
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

  # If you get here, wait_for_connector_to_be_live has not been successful. Run curl with -v
  runi2AnalyzeToolAsGatewayUser bash -c "curl -v --cert /tmp/i2acerts/i2Analyze.pem --cacert /tmp/i2acerts/CA.cer \"${connector_config_url}\""
  printWarn "Connector is NOT live at ${connector_config_url}"
}

# @section Database Security Utilities
# @description

# @description Change the initial password for the SA user.
# Uses the generated secrets to call the change_sa_password.sh with the initial (generated)
# sa password and the new (generated) password.
# For more information, see [change_sa_password](../security%20and%20users/db_users.md#the-changesapassword-function).
# @noargs
function change_sa_password() {
  local SA_PASSWORD
  local SA_INITIAL_PASSWORD
  local SSL_CA_CERTIFICATE
  SA_PASSWORD=$(get_secret sqlserver/sa_PASSWORD)
  SA_INITIAL_PASSWORD=$(get_secret sqlserver/sa_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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
    "/opt/db-scripts/change_sa_password.sh"
}

# @description Change the initial password for the db2inst1 user.
# @noargs
# @internal
function change_db2_inst1_password() {
  local DB2INST1_PASSWORD
  local DB2INST1_INITIAL_PASSWORD
  local SSL_CA_CERTIFICATE
  DB2INST1_PASSWORD=$(get_secret db2server/db2inst1_PASSWORD)
  DB2INST1_INITIAL_PASSWORD=$(get_secret db2server/db2inst1_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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
    "/opt/db-scripts/change_db2_inst1_password.sh"
}

# @description Creates a database login and user for the provided user, and assigns the user to the provided role.
# For more information, see [create_db_login_and_user](../security%20and%20users/db_users.md#the-createdbloginanduser-function).
# @arg $1 string The database user name
# @arg $2 string The database role name
function create_db_login_and_user() {
  validateParameters "2" "$@"

  local user="$1"
  local role="$2"
  local SA_PASSWORD
  local USER_PASSWORD
  local SSL_CA_CERTIFICATE
  SA_PASSWORD=$(get_secret sqlserver/sa_PASSWORD)
  USER_PASSWORD=$(get_secret sqlserver/"${user}"_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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
    "/opt/db-scripts/create_db_login_and_user.sh"
}

# @section Execution Utilities
# @description

# @description Use an ephemeral Solr client container to run commands against Solr.
# For more information about the environment variables and volume mounts that are required for the Solr client, see [Running a Solr client container](../images%20and%20containers/solr_client.md).
# The run_solr_client_command function takes the command you want to run as an argument.
# For more information about commands you can execute using the Solr zkcli, see [Solr ZK Command Line Utilities](https://lucene.apache.org/solr/guide/8_6/command-line-utilities.html)
#
# @example
#    run_solr_client_command "/opt/solr/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
#
# @arg $@ string The command you want to run on the Solr client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_solr_client_command() {
  local ZOO_DIGEST_PASSWORD
  local ZOO_DIGEST_READONLY_PASSWORD
  local SOLR_ADMIN_DIGEST_PASSWORD
  local SECURITY_JSON
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE
  ZOO_DIGEST_PASSWORD=$(get_secret solr/ZK_DIGEST_PASSWORD)
  ZOO_DIGEST_READONLY_PASSWORD=$(get_secret solr/ZK_DIGEST_READONLY_PASSWORD)
  SOLR_ADMIN_DIGEST_PASSWORD=$(get_secret solr/SOLR_ADMIN_DIGEST_PASSWORD)
  SECURITY_JSON=$(get_secret solr/security.json)

  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
    SSL_PRIVATE_KEY=$(get_secret certificates/solrClient/server.key)
    SSL_CERTIFICATE=$(get_secret certificates/solrClient/server.cer)
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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

# @description Run an ephemeral i2 Analyze Tool container to run the i2 Analyze tools.
#
# @example
#    run_i2_analyze_tool "/opt/i2-tools/scripts/updateSecuritySchema.sh"
#
# @arg $@ string Command you want to run on the i2 Analyze Tool container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_i2_analyze_tool() {
  local ZOO_DIGEST_PASSWORD
  local ZOO_DIGEST_READONLY_PASSWORD
  local SOLR_ADMIN_DIGEST_PASSWORD
  local DB_SERVER_FQDN
  local DB_USERNAME
  local DB_PASSWORD
  local SSL_PRIVATE_KEY
  local SSL_CERTIFICATE
  local SSL_CA_CERTIFICATE
  ZOO_DIGEST_PASSWORD=$(get_secret solr/ZK_DIGEST_PASSWORD)
  ZOO_DIGEST_READONLY_PASSWORD=$(get_secret solr/ZK_DIGEST_READONLY_PASSWORD)
  SOLR_ADMIN_DIGEST_PASSWORD=$(get_secret solr/SOLR_ADMIN_DIGEST_PASSWORD)

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(get_secret db2server/db2inst1_PASSWORD)
    DB_SERVER_FQDN="${DB2_SERVER_FQDN}"
    ;;
  sqlserver)
    # shellcheck disable=SC2153
    DB_USERNAME="${DBA_USERNAME}"
    DB_PASSWORD=$(get_secret sqlserver/dba_PASSWORD)
    DB_SERVER_FQDN="${SQL_SERVER_FQDN}"
    ;;
  esac

  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
    SSL_PRIVATE_KEY=$(get_secret certificates/solrClient/server.key)
    SSL_CERTIFICATE=$(get_secret certificates/solrClient/server.cer)
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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

# @description Use an ephemeral i2 Analyze Tool container to run commands against the i2 Analyze service via the load balancer as an external user.
# The container contains the required secrets to communicate with the i2 Analyze service from an external container.
# For example, if you would like to send a Curl request to the load balancer stats endpoint, run:
# @example
#   run_i2_analyze_tool_as_external_user bash -c "curl \
#         --silent \
#         --cookie-jar /tmp/cookie.txt \
#         --cacert /tmp/i2acerts/CA.cer \
#         --request POST \"${FRONT_END_URI}/j_security_check\" \
#         --header 'Origin: ${FRONT_END_URI}' \
#         --header 'Content-Type: application/x-www-form-urlencoded' \
#         --data-urlencode 'j_username=Jenny' \
#         --data-urlencode 'j_password=Jenny' \
#       && curl \
#         --silent \
#         --cookie /tmp/cookie.txt \
#         --cacert /tmp/i2acerts/CA.cer\
#         \"${FRONT_END_URI}/api/v1/admin/indexes/status\""
#
# @arg $@ string Command you want to run on the i2 Analyze Tool container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_i2_analyze_tool_as_external_user() {
  local SSL_CA_CERTIFICATE
  SSL_CA_CERTIFICATE=$(get_secret certificates/externalCA/CA.cer)

  docker run --rm \
    "${EXTRA_ARGS[@]}" \
    -e "SERVER_SSL=true" \
    -e "SSL_CA_CERTIFICATE=${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the etl user.
# For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.html).
# @example
# run_sql_server_command_as_etl bash -c "/opt/mssql-tools/bin/sqlcmd -N -b -S \${DB_SERVER} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} -Q
# \"BULK INSERT IS_Staging.E_Person
# FROM '/var/i2a-data/law-enforcement-data-set-2-merge/person.csv'
# WITH (FORMATFILE = '/var/i2a-data/law-enforcement-data-set-2-merge/sqlserver/format-files/person.fmt', FIRSTROW = 2)\""
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_etl() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/etl_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the
# Information Store database as the i2etl user, such as executing generated drop/create index scripts,
# created by the ETL toolkit.
# For more information about running a SQL Client container and the environment variables required for the
# container, see [SQL Client](../images%20and%20containers/sql_client.html).
# @example
# run_sql_server_command_as_i2_etl bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
#   -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
#   -i /opt/database-scripts/ET5-drop-entity-indexes.sql"
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_i2_etl() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/i2etl_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the
# Information Store database as the sa user with the initial SA password.
# For more information about running a SQL Client container and the environment variables required for the
# container, see [SQL Client](../images%20and%20containers/sql_client.html).
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_first_start_sa() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/sa_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the
# Information Store database as the SA user.
# For more information about running a SQL Client container and the environment variables required for the
# container, see [SQL Client](../images%20and%20containers/sql_client.html).
# @example
#    run_sql_server_command_as_sa "/opt/i2-tools/scripts/database-creation/runStaticScripts.sh"
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_sa() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/sa_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the
# Information Store database as the dba user.
# For more information about running a SQL Client container and the environment variables required for the
# container, see [SQL Client](../images%20and%20containers/sql_client.html).
# @example
#    run_sql_server_command_as_dba "/opt/i2-tools/scripts/clearInfoStoreData.sh"
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_dba() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/dba_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral SQL Client container to run database scripts or commands against the
# Information Store database as the dbb (the backup operator) user.
# For more information about running a SQL Client container and the environment variables required for the
# container, see [SQL Client](../images%20and%20containers/sql_client.html).
# @example
#    run_sql_server_command_as_dbb bash -c "/opt/mssql-tools/bin/sqlcmd -N -b -C -S sqlserver.eia,1433 -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" \
#      -Q \"USE ISTORE;
#      BACKUP DATABASE ISTORE
#      TO DISK = '/backup/istore.bak'
#         WITH FORMAT;\""
#
# @arg $@ string Command you want to run on the SQL Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_sql_server_command_as_dbb() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret sqlserver/dbb_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral ETL toolkit container to run ETL toolkit tasks against the
# Information Store using the i2 ETL user credentials.
# For more information about running the ETL Client container and the environment variables required for the container, see [ETL Client](../images%20and%20containers/etl_client.html).
# For more information about running the ETL toolkit container and the tasks that you can run, see [ETL Tools](../tools%20and%20functions/etl_tools.html)
# @example
#   run_etl_toolkit_tool_as_i2_etl bash -c "/opt/i2/etltoolkit/addInformationStoreIngestionSource --ingestionSourceName EXAMPLE_1 --ingestionSourceDescription EXAMPLE_1"
#
# @arg $@ string Command you want to run on the ETL Toolkit container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_etl_toolkit_tool_as_i2_etl() {
  local DB_USERNAME
  local DB_PASSWORD
  local DB_SERVER_FQDN
  local SSL_CA_CERTIFICATE

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(get_secret db2server/db2inst1_PASSWORD)
    DB_SERVER_FQDN="${DB2_SERVER_FQDN}"
    ;;
  sqlserver)
    DB_USERNAME="${I2_ETL_USERNAME}"
    DB_PASSWORD=$(get_secret sqlserver/i2etl_PASSWORD)
    DB_SERVER_FQDN="${SQL_SERVER_FQDN}"
    ;;
  esac

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_CLIENT_VOLUME_NAME}" "${container_data_dir}"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral ETL toolkit container to run ETL toolkit tasks against the
# Information Store using the DBA user credentials.
# For more information about running the ETL Client container and the environment variables required for the container, see [ETL Client](../images%20and%20containers/etl_client.html).
# For more information about running the ETL toolkit container and the tasks that you can run, see [ETL Tools](../tools%20and%20functions/etl_tools.html)
# @example
#   run_etl_toolkit_tool_as_dba bash -c "/opt/i2/etltoolkit/addInformationStoreIngestionSource --ingestionSourceName EXAMPLE_1 --ingestionSourceDescription EXAMPLE_1"
#
# @arg $@ string Command you want to run on the ETL Toolkit container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
function run_etl_toolkit_tool_as_dba() {
  local DB_USERNAME
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE

  case "${DB_DIALECT}" in
  db2)
    DB_USERNAME="${DB2INST1_USERNAME}"
    DB_PASSWORD=$(get_secret db2server/db2inst1_PASSWORD)
    ;;
  sqlserver)
    DB_USERNAME="${DBA_USERNAME}"
    DB_PASSWORD=$(get_secret sqlserver/dba_PASSWORD)
    ;;
  esac

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_CLIENT_VOLUME_NAME}" "${container_data_dir}"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral Db2 Client container to run database scripts or commands against the
# Information Store database as the db2inst1 user.
# @example
#    run_db2_server_command_as_db2inst1 "/opt/i2-tools/scripts/database-creation/runStaticScripts.sh"
#
# @arg $@ string Command you want to run on the Db2 Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
# @internal
function run_db2_server_command_as_db2inst1() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret db2server/db2inst1_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
  fi

  local container_data_dir="/var/i2a-data"
  update_volume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

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

# @description Uses an ephemeral Db2 Client container to run database scripts or commands against the
# Information Store database as the db2inst1 user with the initial db2inst1 password.
#
# @arg $@ string Command you want to run on the Db2 Client container
#
# @exitcode 0 If command was executed successfully.
# @exitcode 1 If command was NOT executed successfully.
# @internal
function run_db2_server_command_as_first_start_db2inst1() {
  local DB_PASSWORD
  local SSL_CA_CERTIFICATE
  DB_PASSWORD=$(get_secret db2server/db2inst1_INITIAL_PASSWORD)

  if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
    SSL_CA_CERTIFICATE=$(get_secret certificates/CA/CA.cer)
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

# @section Volume utilities
# @description

# @description Uses an ephemeral Red Hat UBI Docker image to update a volume with the contents of a local directory.
# For example, to update the the run/secrets directory in the liberty1_secrets volume with the content of the local /dev-environment-secrets/simulated-secret-store directory, run:
# @example
#   update_volume "/dev-environment-secrets/simulated-secret-store" "liberty1_secrets" "/run/secrets"
#
# @arg $1 string The local directory on your machine.
# @arg $2 string The volume name.
# @arg $3 string The directory inside the volume.
function update_volume() {
  validateParameters "3" "$@"

  local local_dir="$1"
  local volume_name="$2"
  local volume_dir="$3"

  docker run \
    --rm \
    -v "${local_dir}:/run/bind-mount" \
    -v "${volume_name}:${volume_dir}" \
    "${REDHAT_UBI_IMAGE_NAME}:${REDHAT_UBI_IMAGE_VERSION}" \
    bash -c "rm -rf ${volume_dir}/* && cp -r '/run/bind-mount/.' '${volume_dir}'"
}

# @description Uses an ephemeral Red Hat UBI Docker image to update a local directory with the contents of a specified volume.
# For example, to get the contents from the run/secrets directory in the liberty1_secrets volume into your local /dev-environment-secrets/simulated-secret-store directory, run:
# @example
#   get_volume "/dev-environment-secrets/simulated-secret-store" "liberty1_secrets" "/run/secrets"
#
# @arg $1 string The local directory on your machine.
# @arg $2 string The volume name.
# @arg $3 string The directory inside the volume.
function get_volume() {
  validateParameters "3" "$@"

  local local_dir="$1"
  local volume_name="$2"
  local volume_dir="$3"

  # Ensure to canonicalise if it is pointing to a symlink
  host_dir=$(readlink -f "${local_dir}")
  deleteFolderIfExistsAndCreate "${host_dir}"

  docker run \
    --rm \
    -v "${host_dir}:/run/bind-mount" \
    -v "${volume_name}:${volume_dir}" \
    "${REDHAT_UBI_IMAGE_NAME}:${REDHAT_UBI_IMAGE_VERSION}" \
    bash -c "cp -r '${volume_dir}/.' /run/bind-mount && chown -R $(id -u "${USER}"):$(id -g "${USER}") /run/bind-mount"
}

###############################################################################
# End of function definitions.                                                #
###############################################################################

###############################################################################
# Mirror all functions to old names. Deprecation warning shown.
# TODO: Remove on major version
###############################################################################
function checkClientFunctionsEnvironmentVariablesAreSet() {
  printWarn "checkClientFunctionsEnvironmentVariablesAreSet has been deprecated. Please use check_env_vars_are_set instead."
  check_env_vars_are_set "$@"
}
function isSecret() {
  printWarn "isSecret has been deprecated. Please use is_secret instead."
  is_secret "$@"
}
function getSecret() {
  printWarn "getSecret has been deprecated. Please use get_secret instead."
  get_secret "$@"
}
function getSolrStatus() {
  printWarn "getSolrStatus has been deprecated. Please use get_solr_status instead."
  get_solr_status "$@"
}
function getAsyncRequestStatus() {
  printWarn "getAsyncRequestStatus has been deprecated. Please use get_async_request_status instead."
  get_async_request_status "$@"
}
function waitForIndexesToBeBuilt() {
  printWarn "waitForIndexesToBeBuilt has been deprecated. Please use wait_for_indexes_to_be_built instead."
  wait_for_indexes_to_be_built "$@"
}
function waitForConnectorToBeLive() {
  printWarn "waitForConnectorToBeLive has been deprecated. Please use wait_for_connector_to_be_live instead."
  wait_for_connector_to_be_live "$@"
}
function changeSAPassword() {
  printWarn "changeSAPassword has been deprecated. Please use change_sa_password instead."
  change_sa_password "$@"
}
function changeDb2inst1Password() {
  printWarn "changeDb2inst1Password has been deprecated. Please use change_db2_inst1_password instead."
  change_db2_inst1_password "$@"
}
function createDbLoginAndUser() {
  printWarn "createDbLoginAndUser has been deprecated. Please use create_db_login_and_user instead."
  create_db_login_and_user "$@"
}
function runSolrClientCommand() {
  printWarn "runSolrClientCommand has been deprecated. Please use run_solr_client_command instead."
  run_solr_client_command "$@"
}
function runi2AnalyzeTool() {
  printWarn "runi2AnalyzeTool has been deprecated. Please use run_i2_analyze_tool instead."
  run_i2_analyze_tool "$@"
}
function runi2AnalyzeToolAsExternalUser() {
  printWarn "runi2AnalyzeToolAsExternalUser has been deprecated. Please use run_i2_analyze_tool_as_external_user instead."
  run_i2_analyze_tool_as_external_user "$@"
}
function runSQLServerCommandAsETL() {
  printWarn "runSQLServerCommandAsETL has been deprecated. Please use run_sql_server_command_as_etl instead."
  run_sql_server_command_as_etl "$@"
}
function runSQLServerCommandAsi2ETL() {
  printWarn "runSQLServerCommandAsi2ETL has been deprecated. Please use run_sql_server_command_as_i2_etl instead."
  run_sql_server_command_as_i2_etl "$@"
}
function runSQLServerCommandAsFirstStartSA() {
  printWarn "runSQLServerCommandAsFirstStartSA has been deprecated. Please use run_sql_server_command_as_first_start_sa instead."
  run_sql_server_command_as_first_start_sa "$@"
}
function runSQLServerCommandAsSA() {
  printWarn "runSQLServerCommandAsSA has been deprecated. Please use run_sql_server_command_as_sa instead."
  run_sql_server_command_as_sa "$@"
}
function runSQLServerCommandAsDBA() {
  printWarn "runSQLServerCommandAsDBA has been deprecated. Please use run_sql_server_command_as_dba instead."
  run_sql_server_command_as_dba "$@"
}
function runSQLServerCommandAsDBB() {
  printWarn "runSQLServerCommandAsDBB has been deprecated. Please use run_sql_server_command_as_dbb instead."
  run_sql_server_command_as_dbb "$@"
}
function runEtlToolkitToolAsi2ETL() {
  printWarn "runEtlToolkitToolAsi2ETL has been deprecated. Please use run_etl_toolkit_tool_as_i2_etl instead."
  run_etl_toolkit_tool_as_i2_etl "$@"
}
function runEtlToolkitToolAsDBA() {
  printWarn "runEtlToolkitToolAsDBA has been deprecated. Please use run_etl_toolkit_tool_as_dba instead."
  run_etl_toolkit_tool_as_dba "$@"
}
function runDb2ServerCommandAsDb2inst1() {
  printWarn "runDb2ServerCommandAsDb2inst1 has been deprecated. Please use run_db2_server_command_as_db2inst1 instead."
  run_db2_server_command_as_db2inst1 "$@"
}
function runDb2ServerCommandAsAsFirstStartDb2inst1() {
  printWarn "runDb2ServerCommandAsAsFirstStartDb2inst1 has been deprecated. Please use run_db2_server_command_as_first_start_db2inst1 instead."
  run_db2_server_command_as_first_start_db2inst1 "$@"
}
function updateVolume() {
  printWarn "updateVolume has been deprecated. Please use update_volume instead."
  update_volume "$@"
}
function getVolume() {
  printWarn "getVolume has been deprecated. Please use get_volume instead."
  get_volume "$@"
}
