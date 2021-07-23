#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2021, IBM Corporation
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

###############################################################################
# Function definitions start here                                             #
###############################################################################

function deleteContainer() {
  local container_name_or_id="$1"
  local container_id
  local max_retries=10

  # identify if name or id supplied as $1 exists
  container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f name="${container_name_or_id}")"
  if [[ -z "${container_id}" ]]; then
    container_id="$(docker ps -aq -f network="${DOMAIN_NAME}" -f id="${container_name_or_id}")"
    if [[ -z "${container_id}" ]]; then
      printInfo "${container_name_or_id} does NOT exist"
      return 0
    fi
  fi
  print "Stopping ${container_name_or_id} container"
  while ! docker stop "${container_name_or_id}"; do
    if (( "${max_retries}" == 0 )); then
      printErrorAndExit "Unable to stop container '${container_name_or_id}', exiting script"
    else
      echo "[WARN] Having issues stopping container '${container_name_or_id}', retrying..."
      ((max_retries="${max_retries}"-1))
    fi
    sleep 1s
  done
  print "Deleting ${container_name_or_id} container"
  docker rm "${container_name_or_id}"
}

function checkDeploymentIsLive() {
  local config_name="$1"
  local live_flag="true"
  local container_names=("${ZK1_CONTAINER_NAME}" "${SOLR1_CONTAINER_NAME}" "${LIBERTY1_CONTAINER_NAME}" "${SQL_SERVER_CONTAINER_NAME}")
  print "Checking '${config_name}' deployment is live"
  for container_name in "${container_names[@]}"; do
    local container_id
    container_id="$(docker ps -a -q -f network="${DOMAIN_NAME}" -f name="${container_name}" -f "status=running")"
    if [[ -z "${container_id}" ]]; then
      live_flag="false"
      printInfo "${container_id} is not in the 'running' state"
    fi
  done
  if [[ "${live_flag}" == "false" ]]; then
    printErrorAndExit "Deployment is NOT live"
  else
    echo "Deployment is live"
  fi
}

function clearLibertyValidationLog() {
  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c 'rm /logs/opal-services/IBM_i2_Validation.log > /dev/null 2>&1 || true'
  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c 'rm /logs/opal-services/IBM_i2_Status.log > /dev/null 2>&1 || true'
}

function replaceXmlElementWithHeredoc() {
  local xml_element="$1"
  local heredoc_file_path="$2"
  local log4j2_file_path="$3"
  # replace string with contents of a heredoc file, sed explantation:
  # line 1: when you find ${xml_element}
  # line 2: remove ${xml_element}
  # line 3: replace with the content of a file
  # line 4: delete the extra new line
  sed -i "/${xml_element}/{
          s/${xml_element}//g
          r ${heredoc_file_path}
          d
  }" "${log4j2_file_path}"
}

function updateLog4jFile() {
  local properties_heredoc_file_path="/tmp/properties_heredoc"
  local appenders_heredoc_file_path="/tmp/appenders_heredoc"
  local loggers_heredoc_file_path="/tmp/loggers_heredoc"
  local log4j2_file_path="${LOCAL_USER_CONFIG_DIR}/log4j2.xml"
  local tmp_log4j2_file_path="/tmp/log4j2.xml"

  printInfo "Updating Log4j2.xml file"

  # Create tmp log4j2 file
  cp "${log4j2_file_path}" "${tmp_log4j2_file_path}"

  # Creating heredocs
  cat > "${properties_heredoc_file_path}" <<'EOF'
    <Property name="rootDir">${sys:apollo.log.dir}/opal-services</Property>
    <Property name="validationMessagesPatternLayout">%d - %m%n</Property>
    <Property name="archiveDir">${rootDir}/${archiveDirFormat}</Property>
    <Property name="archiveFileDateFormat">%d{dd-MM-yyyy}-%i</Property>
    <Property name="triggerSize">1MB</Property>
    <Property name="maxRollover">10</Property>
  </Properties>
EOF
  cat > "${appenders_heredoc_file_path}" <<'EOF'
    <RollingFile name="VALIDATIONLOG" append="true">
      <FileName>${rootDir}/IBM_i2_Validation.log</FileName>
      <FilePattern>"${archiveDir}/IBM_i2_Validation-${archiveFileDateFormat}.log</FilePattern>
      <PatternLayout charset="UTF-8" pattern="${validationMessagesPatternLayout}" />
      <Policies>
        <SizeBasedTriggeringPolicy size="${triggerSize}" />
      </Policies>
      <DefaultRolloverStrategy max="${maxRollover}" />
    </RollingFile>
    <RollingFile name="STATUSLOG" append="true">
      <FileName>${rootDir}/IBM_i2_Status.log</FileName>
      <FilePattern>"${archiveDir}/IBM_i2_Status-${archiveFileDateFormat}.log</FilePattern>
      <PatternLayout charset="UTF-8" pattern="${validationMessagesPatternLayout}" />
      <Policies>
        <SizeBasedTriggeringPolicy size="${triggerSize}" />
      </Policies>
      <DefaultRolloverStrategy max="${maxRollover}" />
    </RollingFile>
  </Appenders>
EOF
  cat > "${loggers_heredoc_file_path}" <<'EOF'
    <!-- i2Analyze Validation Logging -->
    <Logger name="com.i2group.apollo.common.toolkit.internal.ConsoleLogger" level="WARN" additivity="true">
      <AppenderRef ref="VALIDATIONLOG" />
    </Logger>
    <Logger name="com.i2group.disco.sync.ComponentAvailabilityCheck" level="WARN" additivity="true">
      <AppenderRef ref="VALIDATIONLOG" />
    </Logger>
    <Logger name="com.i2group.opal.daod.mapping.internal" level="WARN" additivity="true">
      <AppenderRef ref="VALIDATIONLOG" />
    </Logger>
    <Logger name="com.i2group.disco.servlet.ApplicationLifecycleManager" level="INFO" additivity="true">
      <AppenderRef ref="STATUSLOG" />
    </Logger>
    <Logger name="com.i2group.disco.sync.ApplicationStateHandler" level="INFO" additivity="true">
      <AppenderRef ref="STATUSLOG" />
    </Logger>
  </Loggers>
EOF

  # Updating Log4j2 file with the heredoc
  replaceXmlElementWithHeredoc "<\/Properties>" "${properties_heredoc_file_path}" "${tmp_log4j2_file_path}"
  replaceXmlElementWithHeredoc "<\/Appenders>" "${appenders_heredoc_file_path}" "${tmp_log4j2_file_path}"
  replaceXmlElementWithHeredoc "<\/Loggers>" "${loggers_heredoc_file_path}" "${tmp_log4j2_file_path}"

  docker cp "${tmp_log4j2_file_path}" "${LIBERTY1_CONTAINER_NAME}:liberty/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/classes"

  # Remove tmp heredoc files
  rm "${properties_heredoc_file_path}" "${appenders_heredoc_file_path}" "${loggers_heredoc_file_path}" "${tmp_log4j2_file_path}"
}

function waitForLibertyToBeLive() {
  print "Waiting for i2Analyze service to be live"
  local MAX_TRIES=10

  for i in $(seq 1 "${MAX_TRIES}"); do
    if curl \
        -s -S -o /tmp/response.txt \
        --cookie /tmp/cookie.txt \
        --write-out "%{http_code}" \
        --silent \
        --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
        "${FRONT_END_URI}/api/v1/health/live" > /tmp/http_code.txt; then
      http_status_code=$(cat /tmp/http_code.txt)
      if [[ "${http_status_code}" -eq 200 ]]; then
        echo "i2Analyze service is live"
        return 0
      else
        echo "Response from the /health/live endpoint: $(cat /tmp/response.txt)"
      fi
    fi
    echo "i2Analyze service is NOT live (attempt: $i). Waiting..."
    sleep 10
  done
  echo "Response from the /health/live endpoint: $(cat /tmp/response.txt)"
  docker logs -n 50 "${LIBERTY1_CONTAINER_NAME}"
  printErrorAndExit "i2Analyze service is NOT live"
}

function checkLibertyStatus() {
  print "Checking Liberty Status"

  local warn_message="Warnings detected, please review the above message(s)."
  local errors_message="Validation errors detected, please review the above message(s)."
  local validation_log_path="/logs/opal-services/IBM_i2_Validation.log"
  local status_log_path="/logs/opal-services/IBM_i2_Status.log"
  local validation_messages

  waitForLibertyToBeLive

  # Wait for a known I2ANALYZE_STATUS code:
  #  0002 is success
  #  0005 is exception on startup
  #  0068 is waiting for component availability
  if docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c "timeout 3m grep -q '0002\|0005\|0068' <(tail -f ${status_log_path})"; then
      validation_messages=$(docker exec "${LIBERTY1_CONTAINER_NAME}" cat "${validation_log_path}")
      if docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c "grep -q '0002' <(cat ${status_log_path})"; then
        if [[ -n "${validation_messages}" ]]; then
          echo "${validation_messages}"
          printWarn "${warn_message}"
        fi
      else
        if [[ -n "${validation_messages}" ]]; then
          echo "${validation_messages}"
          printErrorAndExit "${errors_message}"
        fi
      fi
      echo "No Validation errors detected."
  else
    validation_messages=$(docker exec "${LIBERTY1_CONTAINER_NAME}" cat "${validation_log_path}")
    if [[ -z "${validation_messages}" ]]; then
      docker logs -n 50 "${LIBERTY1_CONTAINER_NAME}"
    else
      echo "${validation_messages}"
    fi
    printErrorAndExit "Liberty failed to start in time. The last messages logged by the server are above."
  fi
}

#######################################
# Wait for a solr Asynchronous process to be completed.
# Arguments:
#   The Asynchronous ID used to monitor the asynchronous operation.
#######################################
function waitForAsyncrhonousRequestStatusToBeCompleted() {
  local async_id="$1"
  local tries=1
  local max_tries=30

  print "Waiting for ${async_id} to be completed"
  while [[ "${tries}" -le "${max_tries}" ]]; do
    response=$(getAsyncRequestStatus "${async_id}")
    if [[ "${response}" == "completed" ]]; then
      echo "${async_id} status has been marked completed" && return 0
    fi

    echo "${async_id} status has not been marked as completed"
    echo "Waiting..."
    sleep 5
    if [[ "${tries}" -ge "${max_tries}" ]]; then
      printErrorAndExit "ERROR: ${async_id} could not be completed: '${response}'"
    fi
    ((tries++))
  done
}




#######################################
# Wait for Solr to be live
# Arguments:
#   Solr node to wait for to be live
#######################################
function waitForSolrToBeLive() {
  local solr_node="$1"
  local max_tries=15
  local can_access_admin_endpoint=true

  print "Waiting for Solr Node to be live: ${solr_node}"

  for i in $(seq 1 "${max_tries}"); do
    status_response=$(getSolrNodeStatus "${solr_node}")
    if [[ "${status_response}" == "ACTIVE" ]]; then
      echo "${solr_node} status: ACTIVE" && return 0
    elif [[ "${status_response}" == "ERROR" ]]; then
      can_access_admin_endpoint=false
    else
      echo "${solr_node} status: DOWN"
    fi
    sleep 5
    echo "(attempt: ${i}). Waiting..."
  done

  # If you get here, getSolrNodeStatus has not been successful
  if [[ "${can_access_admin_endpoint}" == false ]]; then
    runSolrClientCommand bash -c "curl --silent --write-out \"%{http_code}\" \
      --cacert ${CONTAINER_CERTS_DIR}/CA.cer \
      -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" \
      \"${SOLR1_BASE_URL}/solr/admin/info/health\""
    printErrorAndExit "Unable to access ${SOLR1_BASE_URL}/solr/admin/info/health endpoint"
  else
    printErrorAndExit "${solr_node} is NOT live. The list of all live nodes: ${nodes}"
  fi
}

#######################################
# Get Solr node status through Solr API
# Arguments:
#   Solr node to get status of
#######################################
function getSolrNodeStatus() {
  local solr_node="$1"

  if [[ "$(runSolrClientCommand bash -c "curl --silent --output /dev/null --write-out \"%{http_code}\" \
        -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert \"${CONTAINER_CERTS_DIR}/CA.cer\" \
        \"${SOLR1_BASE_URL}/solr/admin/info/health\"")" == 200 ]]; then
    jsonResponse=$(
      runSolrClientCommand bash -c "curl --silent -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" \
          --cacert /tmp/i2acerts/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CLUSTERSTATUS\""
    )
    nodes=$(echo "${jsonResponse}" | jq -r '.cluster.live_nodes | join(", ")')
    if grep -q "${solr_node}" <<<"$nodes"; then
      echo "ACTIVE" && return 0
    fi
    echo "DOWN"
  else
    echo "ERROR can't access admin endpoint"
  fi
}

#######################################
# Get i2 Analyze Service status.
# Arguments:
#   Liberty instance name. E.g liberty1, liberty2 (defaults to 'all').
# Outputs:
#   i2 Analyze service status: Active, Degraded, Down
#######################################
function geti2AnalyzeServiceStatus() {
  local liberty_instance_name="${1:-all}"
  local load_balancer_stats_status_code
  local load_balancer_stats_response
  local liberty_stats
  local liberty_stats_array
  local liberty_name
  local liberty_status
  local liberty_status_number=17

  load_balancer_stats_status_code="$(
    runi2AnalyzeToolAsExternalUser bash -c "curl --write-out \"%{http_code}\" --silent --output /dev/null \
        --cacert /tmp/i2acerts/CA.cer \"${LOAD_BALANCER_STATS_URI}\""
  )"
  # Make sure you get 200 from /haproxy_stats;csv
  if [[ "${load_balancer_stats_status_code}" -eq 200 ]]; then
    # Get Load Balancer Stats
    load_balancer_stats_response="$(
      runi2AnalyzeToolAsExternalUser bash -c "curl  --silent --cacert /tmp/i2acerts/CA.cer \"${LOAD_BALANCER_STATS_URI}\""
    )"
    # Make sure response in not empty
    if [[ -n "${load_balancer_stats_response}" ]]; then
      if [[ "${liberty_instance_name}" == "all" ]]; then
        # Determine whether all Liberty servers are Down
        if grep -q "BACKEND" <<<"${load_balancer_stats_response}"; then
          liberty_stats=$(grep "BACKEND" <<<"${load_balancer_stats_response}")
          # Parse line of csv into a $liberty_stats array
          # IFS is a separator used by the 'read' command
          IFS=',' read -r -a liberty_stats_array <<<"${liberty_stats}"
          liberty_status="${liberty_stats_array[${liberty_status_number}]}"
          if [[ "${liberty_status}" != "UP" ]]; then
            echo "DOWN"
            return
          fi
        fi
        # If Liberty Backend is UP, check whether i2 Analyze Service state is Active or Degraded
        while read -r line; do
          if grep -q "liberty" <<<"${line}"; then
            IFS=',' read -r -a liberty_stats_array <<<"${line}"
            liberty_status="${liberty_stats_array[${liberty_status_number}]}"
            if [[ "${liberty_status}" != "UP" ]]; then
              echo "DEGRADED"
              return
            fi
          fi
        done < <(echo "${load_balancer_stats_response}")
      else
        liberty_stats=$(grep "$liberty_instance_name" <<<"${load_balancer_stats_response}")
        IFS=',' read -r -a liberty_stats_array <<<"${liberty_stats}"
        liberty_status="${liberty_stats_array[${liberty_status_number}]}"
        if [[ "${liberty_status}" != "UP" ]]; then
          echo "DOWN"
          return
        fi
      fi
    else
      echo "Empty response from the load balancer stats page (${LOAD_BALANCER_STATS_URI})"
    fi
  else
    echo "Response from the load balancer stats page (${LOAD_BALANCER_STATS_URI}) is not OK. We are getting: ${load_balancer_stats_status_code}"
  fi
  # IF you get here i2 Analyze Service is UP
  echo "ACTIVE"
}

#######################################
# Get ZooKeeper ensemble service status.
# Arguments:
#   None
# Outputs:
#   ZooKeeper ensemble service status: Active, Degraded, Down
#######################################
function getZkQuorumEnsembleStatus() {
  local online_count=0
  local zookeepers=("${ZK1_FQDN}" "${ZK2_FQDN}" "${ZK3_FQDN}")
  local not_serving_error="This ZooKeeper instance is not currently serving requests"

  for zookeeper in "${zookeepers[@]}"; do
    srvr_endpoint="http://${zookeeper}:8080/commands/srvr"
    if [[ $(runSolrClientCommand bash -c "curl -s --fail --cacert ${CONTAINER_CERTS_DIR}/CA.cer ${srvr_endpoint}") ]]; then
      response=$(runSolrClientCommand bash -c "curl -s --fail --cacert ${CONTAINER_CERTS_DIR}/CA.cer ${srvr_endpoint}")
      error=$(echo "${response}" | jq -r '.error')
      if [[ "${error}" == "null" ]]; then
        ((online_count++))
      elif [[ "${error}" == "${not_serving_error}" ]]; then
        echo "DOWN"
        return
      fi
    fi
  done

  if ((online_count == "${#zookeepers[@]}")); then
    echo "ACTIVE"
  else
    echo "DEGRADED"
  fi
}

#######################################
# Wait for the i2 Analyze Service status to be 'Active'.
# Arguments:
#   None
#######################################
function waitFori2AnalyzeServiceToBeLive() {
  local max_tries=50
  local exit_code=0
  local i2analyze_service_status

  print "Waiting for i2 Analyze service to be live"

  for i in $(seq 1 "${max_tries}"); do
    i2analyze_service_status="$(geti2AnalyzeServiceStatus)"
    if [[ "${i2analyze_service_status}" == "ACTIVE" ]]; then
      exit_code=0
      break
    elif [[ "${i2analyze_service_status}" == "DOWN" ]]; then
      echo "i2 Analyze service state: 'DOWN' (attempt: ${i}). Waiting..."
      exit_code=1
    elif [[ "${i2analyze_service_status}" == "DEGRADED" ]]; then
      echo "i2 Analyze service state: 'DEGRADED' (attempt: ${i}). Waiting..."
      exit_code=2
    fi
    sleep 10
  done

  if [[ "${exit_code}" -eq 0 ]]; then
    echo "i2Analyze service state: 'ACTIVE'"
  elif [[ "${exit_code}" -eq 1 ]]; then
    printErrorAndExit "i2Analyze service state: 'DOWN'"
  elif [[ "${exit_code}" -eq 2 ]]; then
    printErrorAndExit "i2Analyze service state: 'DEGRADED'"
  else
    printErrorAndExit "ERROR: ${i2analyze_service_status}"
  fi
}

#######################################
# Wait for SQL Server to be live. The functions performs
# a simple non consequential query to check whether SQL Server is live.
# Arguments:
#   1 - first_run: {true, false}
#       if 'true' uses the initial SA Password
#       if 'false' uses SA Password
#######################################
function waitForSQLServerToBeLive() {
  local max_tries=15
  local sql_query='SELECT 1'
  local first_run="${1:-false}"
  print "Waiting for SQL Server to be live"
  for i in $(seq 1 "${max_tries}"); do
    if [[ "${first_run}" == "true" ]]; then
      if runSQLServerCommandAsFirstStartSA runSQLQuery "${sql_query}"; then
        echo "SQL Server is live" && return 0
      fi
    else
      if runSQLServerCommandAsSA runSQLQuery "${sql_query}"; then
        echo "SQL Server is live" && return 0
      fi
    fi
    echo "SQL Server is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForSQLServerToBeLive has not been successful
  printErrorAndExit "SQL Server is NOT live."
}

#######################################
# Runs i2 Analyze request as a gateway user
# Arguments:
#   None
#######################################
function runi2AnalyzeToolAsGatewayUser() {
  local SSL_OUTBOUND_PRIVATE_KEY
  local SSL_OUTBOUND_CERTIFICATE
  local SSL_CA_CERTIFICATE
  SSL_OUTBOUND_PRIVATE_KEY=$(getSecret certificates/gateway_user/server.key)
  SSL_OUTBOUND_CERTIFICATE=$(getSecret certificates/gateway_user/server.cer)
  SSL_CA_CERTIFICATE=$(getSecret certificates/CA/CA.cer)

  docker run --rm \
    --network "${DOMAIN_NAME}" \
    -e GATEWAY_SSL_CONNECTION="${GATEWAY_SSL_CONNECTION}" \
    -e SSL_OUTBOUND_PRIVATE_KEY="${SSL_OUTBOUND_PRIVATE_KEY}" \
    -e SSL_OUTBOUND_CERTIFICATE="${SSL_OUTBOUND_CERTIFICATE}" \
    -e SSL_CA_CERTIFICATE="${SSL_CA_CERTIFICATE}" \
    "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Puts a key and value pair in a bash 3 compatible map.
# Arguments:
#   1: The map name
#   2: The key
#   3: The value
#######################################
function map_put() {
  alias "${1}${2}=${3}"
}

#######################################
# Gets a value pair from a bash 3 compatible map.
# Arguments:
#   1: The map name
#   2: The key
# Returns:
#   The value from the specified map
#######################################
function map_get() {
  alias "${1}${2}" | awk -F"'" '{ print $2; }'
}

#######################################
# Gets all the keys from a bash 3 compatible map.
# Arguments:
#   1: The map name
# Returns:
#   The keys from the specified map
#######################################
function map_keys() {
  alias -p | grep "$1" | cut -d'=' -f1 | awk -F"$1" '{print $2; }'
}

#######################################
# Prints a heading style message to the console.
# Arguments:
#   1: The message
#######################################
function print() {
  echo ""
  echo "#----------------------------------------------------------------------"
  echo "# $1"
  echo "#----------------------------------------------------------------------"
}

#######################################
# Prints an error message to the console,
# then exit 1.
# Arguments:
#   1: The message
#######################################
function printErrorAndExit() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
  exit 1
}

#######################################
# Prints an error message to the console
# Arguments:
#   1: The message
#######################################
function printWarn() {
  printf "\n\e[31mWARN: %s\n" "$1" >&2
  printf "\e[0m" >&2
}

#######################################
# Prints an INFO message to the console.
# Arguments:
#   1: The message
#######################################
function printInfo() {
  if [[ "${VERBOSE}" == "true" ]]; then
    printf "[INFO] %s\n" "$1"
  fi
}

#######################################
# Removes Folder if it exists.
# Arguments:
#   1: Folder path
#######################################
function deleteFolderIfExists() {
  local folder_path="$1"
  if [[ -d "${folder_path}" ]]; then
    rm -rf "${folder_path}"
  fi
}

#######################################
# Removes Folder if it exists and create a new one.
# Arguments:
#   1: Folder path
#######################################
function deleteFolderIfExistsAndCreate() {
  local folder_path="$1"

  printInfo "Deleting folder: ${folder_path}"
  deleteFolderIfExists "${folder_path}"

  printInfo "Creating folder: ${folder_path}"
  createFolder "${folder_path}"
}

#######################################
# Create folder if it doesn't exist.
# Arguments:
#   1: Folder path
#######################################
function createFolder() {
  local folder_path="$1"

  if [[ ! -d "${folder_path}" ]]; then
    mkdir -p "${folder_path}"
  fi
}

#######################################
# Create dsis.infostore.properties file
# Arguments:
#   1: dsis.infostore.properties file path.
#######################################
function createDsidInfoStorePropertiesFile() {
  local dsid_properties_file_path="$1"
  local dsid_folder_path
  dsid_folder_path="$(dirname "${dsid_properties_file_path}")"

  if [[ ! -f "${dsid_properties_file_path}" ]]; then
    print "Creating DataSource.properties file"
    createFolder "${dsid_folder_path}"
    {
      echo "DataSourceId=$(uuidgen)"
      echo "DataSourceName=Information Store"
      echo "TopologyId=infostore"
      echo "IsMonitored=true"
    } >"${dsid_properties_file_path}"
  fi
}

#######################################
# Stop docker container
# Arguments:
#   1: container name or id
#######################################
function stopContainer() {
  local container_name_or_id="$1"
  local max_retries=10
  while ! docker stop "${container_name_or_id}"; do
    if (( "${max_retries}" == 0 )); then
      printErrorAndExit "Unable to stop container '${container_name_or_id}', exiting script"
    else
      echo "[WARN] Having issues stopping container '${container_name_or_id}', retrying..."
      ((max_retries="${max_retries}"-1))
    fi
    sleep 1s
  done
}

#######################################
# Remove docker container
# Arguments:
#   1: container name or id
#######################################
function removeContainer() {
  local container_name_or_id="$1"
  local max_retries=10
  while ! docker rm "${container_name_or_id}"; do
    if (( "${max_retries}" == 0 )); then
      printErrorAndExit "Unable to remove container '${container_name_or_id}', exiting script"
    else
      echo "[WARN] Having issues removing container '${container_name_or_id}', retrying..."
      ((max_retries="${max_retries}"-1))
    fi
    sleep 1s
  done
}

#######################################
# Cleans up docker resources for pre-prod:
#   - Stop config-dev containers
#   - Remove pre-prod contaners
#   - Remove pre-prod volumes
# Arguments:
#   None
#######################################
function cleanUpDockerResources() {
  if docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    local container_names
    IFS=' ' read -ra container_names <<< "$(docker ps -a --format "{{.Names}}" -f network="${DOMAIN_NAME}" | xargs)"
    local pre_prod_containers=(
      "${ZK1_CONTAINER_NAME}"
      "${ZK2_CONTAINER_NAME}"
      "${ZK3_CONTAINER_NAME}"
      "${SOLR1_CONTAINER_NAME}"
      "${SOLR2_CONTAINER_NAME}"
      "${SOLR3_CONTAINER_NAME}"
      "${SQL_SERVER_CONTAINER_NAME}"
      "${LIBERTY1_CONTAINER_NAME}"
      "${LIBERTY2_CONTAINER_NAME}"
      "${LOAD_BALANCER_CONTAINER_NAME}"
      "${CONNECTOR1_CONTAINER_NAME}"
      "${CONNECTOR2_CONTAINER_NAME}"
    )

    if [[ "${#container_names[@]}" -gt "0" ]]; then
      print "Stopping all containers"
      for container_name in "${container_names[@]}"; do
        # stop all containers
        stopContainer "${container_name}"
        for pre_prod_container in "${pre_prod_containers[@]}"; do
          if [[ "${container_name}" == "${pre_prod_container}" ]]; then
            # remove only pre-prod containers
            removeContainer "${container_name}"
          fi
        done
      done
    fi
  fi
  # remove volumes
  removeDockerVolumes
}

#######################################
# Removes containers based on the CONFIG_NAME.
# Arguments:
#   None
#######################################
function removeAllContainersForTheConfig() {
  local config_name="$1"
  if docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    local container_ids
    container_ids=$(docker ps -a -q -f network="${DOMAIN_NAME}" -f name="${config_name}")
    if [[ -n "${container_ids}" ]]; then
      print "Removing containers running in the network (${DOMAIN_NAME}) with the config name (${config_name})"
      while IFS= read -r container_id; do
        deleteContainer "${container_id}"
      done <<<"${container_ids}"
    fi
  fi
}

#######################################
# Stops all containers that are NOT required for the current deployment.
# Arguments:
#   None
#######################################
function stopContainersInTheNetwork() {
  local config_name="$1"

  local connector_references_file=${LOCAL_USER_CONFIG_DIR}/connector-references.json
  IFS=' ' read -ra all_connector_names <<< "$( jq -r '.connectors[].name' < "${connector_references_file}" | xargs)"

  local all_connector_container_names
  for connector_name in "${all_connector_names[@]}"; do
    connector_container_name=$(docker ps -a -q -f name="${CONNECTOR_PREFIX}${connector_name}")
    all_connector_container_names="${all_connector_container_names} ${connector_container_name}"
  done

  if docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    local all_container_names
    local required_containers
    container_names_string=$(docker ps -a -q -f network="${DOMAIN_NAME}" -f name="${config_name}" | xargs)
    container_names_string="${container_names_string} ${all_connector_container_names}"

    IFS=' ' read -ra all_container_names <<< "$(docker ps -a -q -f network="${DOMAIN_NAME}" -f status=running | xargs)"
    IFS=' ' read -ra required_containers <<< "${container_names_string}"

    # Delete required container names from the list of the containers to be stopped
    for container_name in "${required_containers[@]}"; do
      for i in "${!all_container_names[@]}"; do
        if [[ "${all_container_names[i]}" == "${container_name}" ]]; then
          unset "all_container_names[i]"
        fi
      done
    done
    if [[ "${#all_container_names[@]}" -gt "0" ]]; then
      # Stop non-required containers for the current deployment
      print "Stopping containers on the ${DOMAIN_NAME} network that aren't for the ${config_name} config"
      for container_name in "${all_container_names[@]}"; do
        if [[ "${container_name}" != "" ]]; then
          docker stop "${container_name}"
        fi
      done
    fi
  fi
}

function restartDockerContainersForConfig() {
  local config_name="$1"
  local sql_server_restarted="false"
  local solr_restarted="false"
  local all_exited_container_names

  IFS=' ' read -ra all_exited_container_names <<< "$(docker ps -a --format "{{.Names}}" -f name="${config_name}" -f status=exited | xargs)"

  if [[ "${#all_exited_container_names[@]}" -gt "0" ]]; then
    print "Restarting containers for config: ${config_name}"
    # Restarting containers
    for container_name in "${all_exited_container_names[@]}"; do
      # if previusly deployed without the isotre don't start it up, should be handled later in the code if needed
      if [[ "${container_name}" == "${SQL_SERVER_CONTAINER_NAME}" ]] && [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" != *"store"* ]]; then
        continue
      fi
      docker start "${container_name}"
      if [[ "${container_name}" == "${SQL_SERVER_CONTAINER_NAME}" ]]; then
        sql_server_restarted="true"
      elif [[ "${container_name}"  == "${SOLR1_CONTAINER_NAME}" ]] || [[ "${container_name}" == "${ZK1_CONTAINER_NAME}" ]]; then
        solr_restarted="true"
      fi
    done

    # Waiting for system to be up
    if [[ "${sql_server_restarted}" == "true" ]]; then
      waitForSQLServerToBeLive
    elif [[ "${solr_restarted}" == "true" ]]; then
      waitForSolrToBeLive "${SOLR1_FQDN}"
    fi
    # if at least one container has been restarted, wait for Liberty to be up
    waitForLibertyToBeLive 
  fi
}

#######################################
# Checks if a volume exists before attempting to remove it.
# This avoids unnecessary console output when a volume does
# not exist.
# Arguments:
#   The name  of the Docker volume to delete
#######################################
function quietlyRemoveDockerVolume() {
  local volume_to_delete="$1"
  local docker_volumes
  docker_volumes="$(docker volume ls -q)"
  if grep -q ^"$volume_to_delete"$ <<<"$docker_volumes"; then
    docker volume rm "$volume_to_delete"
  fi
}

#######################################
# Runs a Solr container as root to change permissions on the Solr backup volume.
# Arguments:
#   None
#######################################
function runSolrContainerWithBackupVolume() {
  docker run --rm \
    -v "${SOLR_BACKUP_VOLUME_NAME}:${SOLR_BACKUP_VOLUME_LOCATION}" \
    --user="root" \
    "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "$@"
}

#######################################
# Removes all the i2Analyze related docker volumes.
# Arguments:
#   None
#######################################
function removeDockerVolumes() {
  print "Removing all associated volumes"
  quietlyRemoveDockerVolume "${SQL_SERVER_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${SQL_SERVER_BACKUP_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${SOLR1_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${SOLR2_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${SOLR3_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK1_DATA_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK2_DATA_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK3_DATA_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK1_DATALOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK2_DATALOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK3_DATALOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK1_LOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK2_LOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${ZK3_LOG_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${LIBERTY1_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${LIBERTY2_VOLUME_NAME}"
  quietlyRemoveDockerVolume "${SOLR_BACKUP_VOLUME_NAME}"
}

#######################################
# Creates docker network if it doesn't exist.
# Arguments:
#   None
#######################################
function createDockerNetwork() {
  if ! docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    print "Creating docker network: ${DOMAIN_NAME}"
    docker network create "${DOMAIN_NAME}"
  fi
}

#######################################
# Prints out the current timestamp,
# in the format that can be passed to the `docker logs`
# with `--since` flag
# Arguments:
#   None
#######################################
function getTimestamp() {
  date --rfc-3339=seconds | sed 's/ /T/'
}

#######################################
# Check variables is set and prints an error if not.
# Arguments:
#   1. Variable value
#   2. Error message to be printed in case of a failure
#######################################
function checkVariableIsSet() {
  local var_value="$1"
  local error_message="$2"
  if [[ -z "${var_value}" ]]; then
    printErrorAndExit "${error_message}"
  fi
}

#######################################
# Checks ENVIRONMENT is a valid environment name.
# Arguments:
#   None
#######################################
function checkEnvironmentIsValid() {
  checkVariableIsSet "${ENVIRONMENT}" "ENVIRONMENT environment variable is not set"
  if [ "${ENVIRONMENT}" != "pre-prod" ] && [ "${ENVIRONMENT}" != "config-dev" ]; then
    printErrorAndExit "${ENVIRONMENT} is not a valid environment name"
  fi
}

#######################################
# Checks DEPLOYMENT_PATTERN is valid.
# Arguments:
#   None
#######################################
function checkDeploymentPatternIsValid() {
  checkVariableIsSet "${DEPLOYMENT_PATTERN}" "DEPLOYMENT_PATTERN environment variable is not set"
  if [ "${DEPLOYMENT_PATTERN}" != "schema_dev" ] && [ "${DEPLOYMENT_PATTERN}" != "istore" ] && [ "${DEPLOYMENT_PATTERN}" != "cstore" ] &&
    [ "${DEPLOYMENT_PATTERN}" != "i2c" ] && [ "${DEPLOYMENT_PATTERN}" != "i2c_istore" ] && [ "${DEPLOYMENT_PATTERN}" != "i2c_cstore" ]; then
    printErrorAndExit "${DEPLOYMENT_PATTERN} is not not a valid deployment pattern"
  fi
}

#######################################
# Checks required containers for the current deploy exist.
# Arguments:
#   None
# Returns:
#   0 - if all exist
#   1 - if >=1 does NOT exist
#######################################
function checkContainersExist() {
  local all_present=0
  local containers=("${SOLR1_CONTAINER_NAME}" "${ZK1_CONTAINER_NAME}" "${LIBERTY1_CONTAINER_NAME}")

  print "Checking all containers required for the deployment exist"
  if [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    containers+=("${SQL_SERVER_CONTAINER_NAME}")
  fi

  for container in "${containers[@]}"; do
    if [[ -z "$( docker ps -aq -f name="${container}")" ]]; then
      echo "${container} does NOT exist"
      all_present=1
    fi
  done

  local connector_references_file="${LOCAL_USER_CONFIG_DIR}/connector-references.json"
  IFS=' ' read -ra all_connector_names <<< "$( jq -r '.connectors[].name' < "${connector_references_file}" | xargs)"
  for container_name in "${all_connector_names[@]}"; do
    if [[ -z "$( docker ps -aq -f name="${CONNECTOR_PREFIX}${container_name}")" ]]; then
      echo "${CONNECTOR_PREFIX}${container_name} does NOT exist"
      all_present=1
    fi
  done

  return "${all_present}"
}

###############################################################################
# End of function definitions.                                                #
###############################################################################
