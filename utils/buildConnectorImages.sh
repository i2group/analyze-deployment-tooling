#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

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

# cspell:ignore ahvyd
while getopts ":e:i:hvy" flag; do
  case "${flag}" in
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
    registry.access.redhat.com/ubi8/nodejs-16 \
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

  # Override settings.json with .env and .env.sample (previously connector.conf.json), if there is none then get the default from the archive
  if findAndCopyFileWithFolderStructure "${CONNECTOR_CONFIG_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${CONNECTOR_CONFIG_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi
  if findAndCopyFileWithFolderStructure "${CONNECTOR_ENV_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${CONNECTOR_ENV_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi
  if findAndCopyFileWithFolderStructure "${CONNECTOR_ENV_SAMPLE_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${CONNECTOR_ENV_SAMPLE_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi
  if findAndCopyFileWithFolderStructure "${OLD_CONNECTOR_CONFIG_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${OLD_CONNECTOR_CONFIG_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
  fi

  # Override previously connector.secrets.json, if there is none then get the default from the archive
  if findAndCopyFileWithFolderStructure "${OLD_CONNECTOR_SECRETS_FILE}" "${connector_dir}/.app" "${connector_dir}/app"; then
    findAndCopyFileWithFolderStructure "${OLD_CONNECTOR_SECRETS_FILE}" "${connector_dir}/app" "${connector_dir}/.app"
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

function buildConnectorImages() {
  local connector_image_dir
  print "Building connectors"

  for connector_name in "${CONNECTOR_NAMES[@]}"; do
    connector_image_dir="${CONNECTOR_IMAGES_DIR}/${connector_name}"
    [[ ! -d "${connector_image_dir}" ]] && continue

    if ! checkConnectorChanged "${connector_name}"; then
      continue
    fi
    if [[ "${connector_type}" != "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
      deleteContainer "${CONNECTOR_PREFIX}${connector_name}"
    fi
    buildImage "${connector_image_dir}"

    # Update old shasum for connector
    mv "${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector_name}.sha512.new" "${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector_name}.sha512"
  done
}

function buildImage() {
  local connector_image_dir="${1}"
  local connector_name="${connector_image_dir##*/}"
  local connector_tag
  local connector_type

  connector_type=$(jq -r '.type' <"${connector_image_dir}/connector-definition.json")

  if [[ "${connector_type}" == "${EXTERNAL_CONNECTOR_TYPE}" ]]; then
    return
  fi

  # Validate connector and sdk versions
  if [[ "${connector_type}" == "${I2CONNECT_SERVER_CONNECTOR_TYPE}" ]]; then
    extractConnectorDist "${connector_name}"
    validateConnectorVersion "${connector_name}" "${connector_type}" || (cleanUpConnectorDist "${connector_name}" && exit 1)
  fi

  connector_tag=$(jq -r '.tag' <"${connector_image_dir}/connector-version.json")

  # Set connector image name
  connector_image_name="${CONNECTOR_IMAGE_BASE_NAME}${connector_name}:${connector_tag}"

  # Build the image
  print "Building connector image: ${connector_image_name}"
  docker build -t "${connector_image_name}" "${CONNECTOR_IMAGES_DIR}/${connector_name}"

  if [[ "${connector_type}" == "${I2CONNECT_SERVER_CONNECTOR_TYPE}" ]]; then
    cleanUpConnectorDist "${connector_name}"
  fi
}

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
# Build Connector Images                                                      #
###############################################################################
buildConnectorImages
