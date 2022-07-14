#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
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

set -e

function printUsage() {
  echo "Usage:"
  echo "  buildConnectorImages.sh"
  echo "  buildConnectorImages.sh -a -d <deployment_name>" 1>&2
  echo "  buildConnectorImages.sh [-i <connector1_name>] [-e <connector1_name>]" 1>&2
  echo "  buildConnectorImages.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -a Produce or use artifacts on AWS." 1>&2
  echo "  -d <deployment_name>  Name of deployment to use on AWS." 1>&2
  echo "  -i <connector_name>   Names of the connectors to deploy and update. To specify multiple connectors, add additional -i options." 1>&2
  echo "  -e <connector_name>   Names of the connectors to deploy and update. To specify multiple connectors, add additional -e options." 1>&2
  echo "  -v                    Verbose output." 1>&2
  echo "  -y                    Answer 'yes' to all prompts." 1>&2
  echo "  -h Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"

# cspell:ignore ahvyd
while getopts "ahvyd:e:i:" flag; do
  case "${flag}" in
  a)
    AWS_ARTIFACTS="true"
    ;;
  d)
    DEPLOYMENT_NAME="${OPTARG}"
    ;;
  i)
    INCLUDED_CONNECTORS+=("$OPTARG")
    ;;
  e)
    EXCLUDED_CONNECTORS+=("${OPTARG}")
    ;;
  y)
    YES_FLAG="true"
    ;;
  v)
    VERBOSE="true"
    ;;
  h)
    help
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

if [[ -z "${ENVIRONMENT}" ]]; then
  ENVIRONMENT="config-dev"
fi

if [[ "${AWS_ARTIFACTS}" && -z "${DEPLOYMENT_NAME}" ]]; then
  usage
fi

if [[ -z "${YES_FLAG}" ]]; then
  YES_FLAG="false"
fi

if [[ "${INCLUDED_CONNECTORS[*]}" && "${EXCLUDED_CONNECTORS[*]}" ]]; then
  printf "\e[31mERROR: Incompatible options: Both (-i) and (-e) were specified.\n" >&2
  printf "\e[0m" >&2
  usage
  exit 1
fi

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

function removeConnectors() {
  print "Removing running connector containers"
  local all_connector_names
  IFS=' ' read -ra all_connector_names <<<"$(docker ps -a --format "{{.Names}}" -f network="${DOMAIN_NAME}" -f name="^${CONNECTOR_PREFIX}" | xargs)"
  for container_name in "${all_connector_names[@]}"; do
    connector_image_name=${container_name#"${CONNECTOR_PREFIX}"}
    if [[ " ${CONNECTOR_NAMES[*]} " == *" ${connector_image_name} "* ]]; then
      deleteContainer "${container_name}"
    fi
  done
}

function validateConnectorDefinition() {
  local connector_definition_file_path="$1"
  local not_valid_error_message="${connector_definition_file_path} is NOT valid"
  local valid_json

  print "Validating ${connector_definition_file_path}"

  type="$(jq -r type <"${connector_definition_file_path}" || true)"

  if [[ "${type}" == "object" ]]; then
    valid_json=$(jq -r '. | select(has("id") and has("name") and has("description") and has("gatewaySchema") and has("configurationPath") and (has("type")==false // .type=="external" and has("baseUrl") // .type!="external"))' <"${connector_definition_file_path}")
    if [[ -z "${valid_json}" ]]; then
      printErrorAndExit "${not_valid_error_message}"
    fi
  else
    printErrorAndExit "${not_valid_error_message}"
  fi
}

function validateConnectorUrlMappings() {
  local connector_url_mappings_file="${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json"
  local not_valid_error_message="${connector_url_mappings_file} is NOT valid"
  local valid_json

  print "Validating ${connector_url_mappings_file}"

  type="$(jq -r type <"${connector_url_mappings_file}" || true)"

  if [[ "${type}" == "array" ]]; then
    valid_json=$(jq -r '.[] | select(has("id") and has("baseUrl"))' <"${connector_url_mappings_file}")
    if [[ -z "${valid_json}" ]]; then
      printErrorAndExit "${not_valid_error_message}"
    fi
  else
    printErrorAndExit "${not_valid_error_message}"
  fi
}

function validateConnectorSecrets() {
  local connector_name="$1"
  local connector_secrets_file_path="${LOCAL_KEYS_DIR}/${connector_name}"
  local not_valid_error_message="Secrets have not been created for the ${connector_name} connector"

  print "Validating ${connector_secrets_file_path}"
  if [ ! -d "${connector_secrets_file_path}" ]; then
    printErrorAndExit "${not_valid_error_message}"
  fi
}

function deployConnectors() {
  local connector_image_dir

  print "Deploying connectors"
  for connector_name in "${CONNECTOR_NAMES[@]}"; do
    connector_image_dir=${CONNECTOR_IMAGES_DIR}/${connector_name}
    [[ ! -d "${connector_image_dir}" ]] && continue
    deployConnector "${connector_name}"
  done
}

function deployConnector() {
  local connector_name="${1}"
  local connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
  local connector_url_mappings_file="${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json"
  local temp_file="${CONNECTOR_IMAGES_DIR}/temp.json"
  local connector_type
  local base_url

  # Validation
  connector_definition_file_path="${connector_image_dir}/connector-definition.json"
  validateConnectorDefinition "${connector_definition_file_path}"

  # Definitions
  configuration_path=$(jq -r '.configurationPath' <"${connector_definition_file_path}")
  connector_id=$(jq -r '.id' <"${connector_definition_file_path}")
  connector_type=$(jq -r '.type' <"${connector_definition_file_path}")
  connector_exists=$(jq -r --arg connector_id "${connector_id}" 'any(.[]; .id==$connector_id)' <"${connector_url_mappings_file}")
  validateConnectorSecrets "${connector_name}"

  # Run connector if not external
  if [[ "${connector_type}" != "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
    local connector_tag connector_fqdn

    connector_tag=$(jq -r '.tag' <"${connector_image_dir}/connector-version.json")
    connector_fqdn="${connector_name}-${connector_tag}.${DOMAIN_NAME}"
    base_url="https://${connector_fqdn}:3443"

    # Start up the connector
    runConnector "${CONNECTOR_PREFIX}${connector_name}" "${connector_fqdn}" "${connector_name}" "${connector_tag}"
    waitForConnectorToBeLive "${connector_fqdn}" "${configuration_path}"

    # Work out if the connector was running previously
    local was_running="false"
    for previously_running_connector_name in "${ALL_RUNNING_CONTAINER_NAMES[@]}"; do
      if [[ "${previously_running_connector_name}" == "${CONNECTOR_PREFIX}${connector_name}" ]]; then
        was_running="true"
      fi
    done

    # If connector was not running previously stop it
    if [[ "${was_running}" != "true" ]]; then
      print "Stopping connector: ${CONNECTOR_PREFIX}${connector_name}"
      docker stop "${CONNECTOR_PREFIX}${connector_name}"
    fi
  else
    base_url=$(jq -r '.baseUrl' <"${connector_definition_file_path}")
  fi

  # Update connector-url-mappings-file.json file
  # shellcheck disable=SC2016
  if [[ "${connector_exists}" == "true" ]]; then
    # Update
    jq -r \
      --arg base_url "${base_url}" \
      --arg connector_id "${connector_id}" \
      ' .[] |= (select(.id==$connector_id) |= (.baseUrl = $base_url))' \
      <"${connector_url_mappings_file}" >"${temp_file}"
  else
    # Insert
    jq -r \
      --arg base_url "${base_url}" \
      --arg connector_id "${connector_id}" \
      '. += [{id: $connector_id, baseUrl: $base_url}]' \
      <"${connector_url_mappings_file}" >"${temp_file}"
  fi
  mv "${temp_file}" "${connector_url_mappings_file}"

  validateConnectorUrlMappings
}

function validateConnectorVersion() {
  local connector_name="$1"
  local connector_type="$2"
  local config_connector_version
  local declared_connector_version
  local config_i2connect_server_version
  local declared_i2connect_server_version
  local connector_version_file_path="${CONNECTOR_IMAGES_DIR}/${connector_name}/connector-version.json"
  local package_json_file_path="${CONNECTOR_IMAGES_DIR}/${connector_name}/app/package.json"
  local i2connect_version_file_path="${CONNECTOR_IMAGES_DIR}/i2connect-server-version.json"

  config_connector_version=$(jq -r '.version' <"${connector_version_file_path}")
  declared_connector_version=$(jq -r '.version' <"${package_json_file_path}")
  config_i2connect_server_version=$(jq -r '.version' <"${i2connect_version_file_path}")
  declared_i2connect_server_version=$(jq -r '.dependencies."@i2analyze/i2connect"' <"${package_json_file_path}")

  print "Running validatei2ConnectVersions tool"

  docker run -it --rm \
    -e "CONNECTOR_NAME=${connector_name}" \
    -e "CONNECTOR_TYPE=${connector_type}" \
    -e "CONFIG_I2CONNECT_SERVER_VERSION=${config_i2connect_server_version}" \
    -e "DECLARED_I2CONNECT_SERVER_VERSION=${declared_i2connect_server_version}" \
    -e "CONFIG_CONNECTOR_VERSION=${config_connector_version}" \
    -e "DECLARED_CONNECTOR_VERSION=${declared_connector_version}" \
    -e "YES_FLAG=${YES_FLAG}" \
    -v "${ANALYZE_CONTAINERS_ROOT_DIR}/utils:/opt/utils" \
    registry.access.redhat.com/ubi8/nodejs-14 \
    "/opt/utils/containers/validatei2ConnectVersions.sh"
}

function findAndCopyFileWithFolderStructure() {
  local file_name="${1}"
  local from_folder="${2}"
  local to_folder="${3}"
  local result

  pushd "${from_folder}" >/dev/null
  result=$(find . -name "${file_name}" -type f -exec cp --parents {} "${to_folder}" \;)
  popd >/dev/null
  [[ -z "${result}" ]]
}

function extractConnectorDist() {
  local connector_name="${1}"
  local connector_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
  local archive_files

  readarray -d '' archive_files < <(find -L "${connector_dir}" -maxdepth 1 \( -name "*.tgz" -o -name "*.tar.gz" \) -type f -print0)

  if [[ "${#archive_files[@]}" -gt 1 ]]; then
    printErrorAndExit "There is more than one .tgz archive in the ${connector_name} directory. Ensure that only one .tgz file is present."
  fi

  if [[ ! -f "${archive_files[0]}" ]]; then
    printErrorAndExit "Cannot find a .tgz archive in the ${connector_name} directory. Ensure that there is a .tgz file present."
  fi
  deleteFolderIfExistsAndCreate "${connector_dir}/.app"
  cp -Rf "${connector_dir}/app/." "${connector_dir}/.app"
  tar -zxf "${archive_files[0]}" --strip-components=1 -C "${connector_dir}/app"

  # Override connector.conf.json, if there is none then get the default from the archive
  if findAndCopyFileWithFolderStructure "${CONNECTOR_CONFIG_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${CONNECTOR_CONFIG_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi

  # Override connector.secrets.json, if there is none then get the default from the archive
  if findAndCopyFileWithFolderStructure "${CONNECTOR_SECRETS_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${CONNECTOR_SECRETS_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi
}

function cleanUpConnectorDist() {
  local connector_name="${1}"
  local connector_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"

  deleteFolderIfExists "${connector_dir}/app"
  #Restore to before build stage
  cp -R "${connector_dir}/.app/." "${connector_dir}/app"
  deleteFolderIfExists "${connector_dir}/.app"
}

function buildImages() {
  local connector_image_dir
  print "Building connector images"

  for connector_name in "${CONNECTOR_NAMES[@]}"; do
    connector_image_dir=${CONNECTOR_IMAGES_DIR}/${connector_name}
    [[ ! -d "${connector_image_dir}" ]] && continue
    buildImage "${connector_image_dir}"
  done
}

function buildImage() {
  local connector_image_dir="${1}"
  local connector_name="${connector_image_dir##*/}"
  local connector_tag
  local connector_type

  connector_type=$(jq -r '.type' <"${connector_image_dir}/connector-definition.json")

  # Validate connector and sdk versions
  if [[ "${connector_type}" == "${I2CONNECT_SERVER_CONNECTOR_TYPE}" ]]; then
    extractConnectorDist "${connector_name}"
    validateConnectorVersion "${connector_name}" "${connector_type}" || (cleanUpConnectorDist "${connector_name}" && exit 1)
  elif [[ "${connector_type}" == "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
    return
  fi

  connector_tag=$(jq -r '.tag' <"${connector_image_dir}/connector-version.json")

  # Set connector image name
  connector_image_name="${CONNECTOR_IMAGE_BASE_NAME}${connector_name}:${connector_tag}"

  if [[ "${AWS_ARTIFACTS}" == "true" ]]; then
    if [[ "${connector_type}" == "${I2CONNECT_SERVER_CONNECTOR_TYPE}" ]] && isSecret "secrets/${connector_name}"; then
      mkdir -p "${CONNECTOR_IMAGES_DIR}/${connector_name}/app/dist/connectors/${connector_name}"
      getSecret "secrets/${connector_name}" >"${CONNECTOR_IMAGES_DIR}/${connector_name}/app/dist/connectors/${connector_name}/${CONNECTOR_CONFIG_FILE}"
    fi
  fi

  # Build the image
  print "Building connector image: ${connector_image_name}"
  docker build -t "${connector_image_name}" "${CONNECTOR_IMAGES_DIR}/${connector_name}"

  if [[ "${connector_type}" == "${I2CONNECT_SERVER_CONNECTOR_TYPE}" ]]; then
    cleanUpConnectorDist "${connector_name}"
  fi
}

if [[ "${AWS_ARTIFACTS}" == "true" ]]; then
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_BASE_NAME}"
fi

createDockerNetwork "${DOMAIN_NAME}"

###############################################################################
# Set a list of all running containers                                        #
###############################################################################
IFS=' ' read -ra ALL_RUNNING_CONTAINER_NAMES <<<"$(docker ps --format "{{.Names}}" -f network="${DOMAIN_NAME}" -f name="^${CONNECTOR_PREFIX}" | xargs)"

###############################################################################
# Set a list of connectors to update                                          #
###############################################################################
setListOfConnectorsToUpdate

###############################################################################
# Clean up                                                                    #
###############################################################################
removeConnectors

###############################################################################
# Build Images                                                                #
###############################################################################
buildImages

###############################################################################
# Deploy Containers                                                           #
###############################################################################
deployConnectors
