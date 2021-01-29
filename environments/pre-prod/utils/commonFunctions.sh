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

#######################################
# Wait for solr to be live
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
# Get solr node status through Solr API
# Arguments:
#   Solr node to get status of
#######################################
function getSolrNodeStatus() {
  local solr_node="$1"

  if [[ "$(runSolrClientCommand bash -c "curl --silent --output /dev/null --write-out \"%{http_code}\" \
        -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert "${CONTAINER_CERTS_DIR}/CA.cer" \
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
#   i2 Analyze service status: Active, Degarded, Down
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
          # IFS is a seperator used by the 'read' command
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
# Wait for Sql Server to be live. The functions performs
# a simple non consequential query to check whether SQL Server is live.
# Arguments:
#   None
#######################################
function waitForSQLServerToBeLive() {
  local max_tries=15

  print "Waiting for Sql Server to be live"
  for i in $(seq 1 "${max_tries}"); do
    if runSQLServerCommandAsFirstStartSA bash -c "${SQLCMD} ${SQLCMD_FLAGS} -C -S ${SQL_SERVER_FQDN},${DB_PORT} \
      -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" -Q 'SELECT 1'" >/dev/null; then
      echo "SQL Server is live" && return 0
    fi
    echo "SQL Server is NOT live (attempt: ${i}). Waiting..."
    sleep 5
  done

  # If you get here, waitForSQLServerToBeLive has not been succesfull
  runSQLServerCommandAsFirstStartSA bash -c "${SQLCMD} ${SQLCMD_FLAGS} -C -S ${SQL_SERVER_FQDN},${DB_PORT} \
    -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" -Q 'SELECT 1'"
  printErrorAndExit "SQL Server is NOT live."
}

#######################################
# Runs i2 analyze request as a gateway user
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
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
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
  exit 1
}

#######################################
# Removes Folder if it exists.
# Arguments:
#   1: Folder path
#######################################
function deleteFolderIfExists() {
  local folder_pah="$1"
  if [[ -d "${folder_pah}" ]]; then
    rm -rf "${folder_pah}"
  fi
}

#######################################
# Removes all containers and the docker network.
# Arguments:
#   None
#######################################
function removeAllContainersAndNetwork() {
  if docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    local container_names
    container_names=$(docker ps -a -q -f network="${DOMAIN_NAME}")
    if [[ -n "${container_names}" ]]; then
      print "Removing all containers running in the network: ${DOMAIN_NAME}"
      while IFS= read -r container_name; do
        docker stop "${container_name}"
        docker rm "${container_name}"
      done <<<"${container_names}"
    fi
    print "Removing docker bridge network: ${DOMAIN_NAME}"
    docker network rm "${DOMAIN_NAME}"
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
# Removes all the i2Analyze related docker volumes.
# Arguments:
#   None
#######################################
function removeDockerVolumes() {
  print "Removing all associated volumes"
  quietlyRemoveDockerVolume "${SQL_SERVER_VOLUME_NAME}"
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

###############################################################################
# End of function definitions.                                                #
###############################################################################
