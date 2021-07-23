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

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

function printUsage() {
  echo "Usage:"
  echo "  buildConnectorImages.sh"
  echo "  buildConnectorImages.sh -a -d <deployment_name> -l <dependency_label>" 1>&2
  echo "  buildConnectorImages.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -a Produce or use artefacts on AWS." 1>&2
  echo "  -d <deployment_name>  Name of deployment to use on AWS." 1>&2
  echo "  -l <dependency_label> Name of dependency image label to use on AWS." 1>&2
  echo "  -h Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"
while getopts "ahd:l:" flag; do
  case "${flag}" in
  a)
    AWS_ARTEFACTS="true"
    ;;
  d)
    DEPLOYMENT_NAME="${OPTARG}"
    ;;
  l)
    I2A_DEPENDENCIES_IMAGES_TAG="${OPTARG}"
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

if [[ "${AWS_ARTEFACTS}" && ( -z "${DEPLOYMENT_NAME}" || -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ) ]]; then
  usage
fi

if [[ -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
  I2A_DEPENDENCIES_IMAGES_TAG="latest"
fi

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

function removeAllConnectors() {
  print "Removing all running connector containers"
  local all_connector_names
  IFS=' ' read -ra all_connector_names <<< "$(docker ps -a --format "{{.Names}}" -f network="${DOMAIN_NAME}" -f name="${CONNECTOR_PREFIX}" | xargs)"
  for container_name in "${all_connector_names[@]}"; do
    deleteContainer "${container_name}"
  done
}

function validateConnectorDefinition() {
  local connector_definition_file_path="$1"
  local not_valid_error_message="${connector_definition_file_path} is NOT valid"
  local valid_json

  print "Validating ${connector_definition_file_path}"

  type="$(jq -r type <"${connector_definition_file_path}" || true)"

  if [[ "${type}" == "object" ]]; then
    valid_json=$(jq -r '. | select(has("id") and has("name") and has("description") and has("gatewaySchema") and has("configurationPath"))' <"${connector_definition_file_path}")
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
  local connector_fqdn
  local connector_name
  local connector_image_name
  local connector_definition_file_path
  local connector_url_mappings_file="${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json"
  local temp_file="${CONNECTOR_IMAGES_DIR}/temp.json"

  # Empty connector-url-mappings-file.json file
  jq -n '. += []' >"${connector_url_mappings_file}"

  print "Deploying all connector containers"

  for connector_image_dir in "${CONNECTOR_IMAGES_DIR}"/*; do
    if [ -d "${connector_image_dir}" ]; then
      # Validation
      connector_definition_file_path="${connector_image_dir}/connector-definition.json"
      validateConnectorDefinition "${connector_definition_file_path}"

      # Definitions
      connector_name="${connector_image_dir##*/}"
      version=$(jq -r '.version' <"${connector_image_dir}/connector-version.json")
      configuration_path=$(jq -r '.configurationPath' <"${connector_definition_file_path}")
      connector_id=$(jq -r '.id' <"${connector_definition_file_path}")
      connector_fqdn="${connector_name}-${version}.${DOMAIN_NAME}"

      validateConnectorSecrets "${connector_name}"

      # Start up the connector
      runConnector "${CONNECTOR_PREFIX}${connector_name}" "${connector_fqdn}" "${connector_name}" "${version}"
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

      # Update connector-url-mappings-file.json file
      jq -r \
        --arg connector_fqdn "https://${connector_fqdn}:3700" \
        --arg connector_id "${connector_id}" \
        '. += [{id: $connector_id, baseUrl: $connector_fqdn}]' \
        <"${connector_url_mappings_file}" >"${temp_file}"
      mv "${temp_file}" "${connector_url_mappings_file}"
    fi
  done

  validateConnectorUrlMappings
}

function buildImages() {
  local connector_name
  local connector_image_name

  print "Building all connector images"

  for connector_image_dir in "${CONNECTOR_IMAGES_DIR}"/*; do
    if [ -d "${connector_image_dir}" ]; then
      # Set connector name and version
      connector_name="${connector_image_dir##*/}"
      version=$(jq -r '.version' <"${connector_image_dir}/connector-version.json")

      # Set connector image name
      connector_image_name="${CONNECTOR_IMAGE_BASE_NAME}${connector_name}:${version}"

      # Build the image
      print "Building connector image: ${connector_image_name}"
      docker build -t "${connector_image_name}" "${CONNECTOR_IMAGES_DIR}/${connector_name}" \
        --build-arg BASE_IMAGE="${SEL_CONNECTOR_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
    fi
  done
}

if [[ "${AWS_ARTEFACTS}" == "true" ]]; then
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_BASE_NAME}"
fi

createDockerNetwork

###############################################################################
# Set a list of all running containers                                        #
###############################################################################
IFS=' ' read -ra ALL_RUNNING_CONTAINER_NAMES <<< "$(docker ps -a --format "{{.Names}}" -f network="${DOMAIN_NAME}" -f name="${CONNECTOR_PREFIX}" -f "status=running" | xargs)"

###############################################################################
# Clean up                                                                    #
###############################################################################
removeAllConnectors

###############################################################################
# Build Images                                                                #
###############################################################################
buildImages

###############################################################################
# Deploy Containers                                                           #
###############################################################################
deployConnectors
