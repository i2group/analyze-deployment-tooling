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
# Puts a key and value pair in a bash 3 compatible map.
# Arguments:
#   1: The map name
#   2: The key
#   3: The value
#######################################
function map_put() {
  alias "${1}${2}"="${3}"
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
# Removes Folder if it exists,
# Arguments:
#   1: The Folder
#######################################
function deleteFolderIfExists() {
  local FOLDER=${1}

  if [[ -d "${FOLDER}" ]]; then
    rm -rf "${FOLDER}"
  fi
}

#######################################
# Removes all containers and the docker network.
# Arguments:
#   None
#######################################
function removeAllContainersAndNetwork() {
  if docker network ls | grep -q -w "${DOMAIN_NAME}"; then
    local CONTAINER_NAMES
    CONTAINER_NAMES=$(docker ps -a -q -f network="${DOMAIN_NAME}")
    if [[ -n "${CONTAINER_NAMES}" ]]; then
      print "Removing all containers running in the network: ${DOMAIN_NAME}"
      while IFS= read -r container_name; do
        docker stop "${container_name}"
        docker rm "${container_name}"
      done <<<"${CONTAINER_NAMES}"
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
  local VOLUME_TO_DELETE="$1"
  local DOCKER_VOLUMES
  DOCKER_VOLUMES="$(docker volume ls -q)"
  if [[ "$DOCKER_VOLUMES" =~ .*"$VOLUME_TO_DELETE".* ]]; then
    docker volume rm "$VOLUME_TO_DELETE"
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

###############################################################################
# End of function definitions.                                                #
###############################################################################
