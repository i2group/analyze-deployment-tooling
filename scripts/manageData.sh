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

echo "BASH_VERSION: $BASH_VERSION"
set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

function printUsage() {
  echo "Usage:"
  echo "  manageData.sh -c <config_name> -t {ingest} -d <data_set> -s <script_name> [-v]"
  echo "  manageData.sh -c <config_name> -t {sources} [-s <script_name>] [-v]"
  echo "  manageData.sh -c <config_name> -t {delete} [-v]"
  echo "  manageData.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -c <config_name>             Name of the config to use." 1>&2
  echo "  -t {delete|ingest|sources}  The task to run. Either delete or ingest data, or add ingestion sources. Delete permanently removes all data from the database." 1>&2
  echo "  -d <data_set>                Name of the data set to ingest." 1>&2
  echo "  -s <script_name>             Name of the ingestion script file. If running the 'sources' task, this will default to 'createIngestionSources.sh'" 1>&2
  echo "  -v                           Verbose output." 1>&2
  echo "  -h                           Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"

while getopts ":t:c:d:s:vh" flag; do
  case "${flag}" in
  t)
    TASK="${OPTARG}"
    ;;
  c)
    CONFIG_NAME="${OPTARG}"
    ;;
  d)
    DATA_SET="${OPTARG}"
    ;;
  s)
    SCRIPT_NAME="${OPTARG}"
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

if [[ -z "${CONFIG_NAME}" ]]; then
  usage
fi

if [[ "${TASK}" != "ingest" ]] && [[ "${TASK}" != "delete" ]] && [[ "${TASK}" != "sources" ]]; then
  usage
fi

if [[ "${TASK}" == "ingest" ]]; then
  if [[ -z "${DATA_SET}" ]] || [[ -z "${SCRIPT_NAME}" ]]; then
    usage
  fi
fi

I2A_DEPENDENCIES_IMAGES_TAG="latest"
I2A_LIBERTY_CONFIGURED_IMAGE_TAG="${CONFIG_NAME}"

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/configs/${CONFIG_NAME}/utils/variables.sh"
source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

function runScript() {
  local script_path="$1"

  if [[ ! -f "${script_path}" ]]; then
    printErrorAndExit "${script_path} doesn't exist"
  fi

  print "Running $1"
  . "${script_path}"
}

function runIngestionScript() {
  local script_path="${ROOT_DIR}/i2a-data/${DATA_SET}/scripts/${SCRIPT_NAME}"
  runScript "${script_path}"
}

function createIngestionSources() {
  local script_name="$1"
  local default_script_name="createIngestionSources.sh"
  local script_path

  if [[ -z "${script_name}" ]]; then
    script_path="${LOCAL_USER_CONFIG_DIR}/ingestion/scripts/${default_script_name}"
  else
    script_path="${LOCAL_USER_CONFIG_DIR}/ingestion/scripts/${script_name}"
  fi

  runScript "${script_path}"
}

function clearSearchIndex() {
  print "Clearing the search index"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/main_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index1/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/match_index2/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/chart_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/daod_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/highlight_index/update?commit=true\" -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""

  # Remove the collection properties from ZooKeeper
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index1/collectionprops.json"
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index2/collectionprops.json"
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/chart_index/collectionprops.json"
}

function clearInfoStore() {
  print "Clearing the InfoStore database"
  case "${DB_DIALECT}" in
    db2)
      runDb2ServerCommandAsDb2inst1 "/opt/databaseScripts/generated/runClearInfoStoreData.sh"
      ;;
    sqlserver)
      runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runClearInfoStoreData.sh"
      ;;
  esac
}

function runClearData() {
  print "Clearing Data"
  clearSearchIndex
  clearInfoStore
}

function removeLibertyContainer() {
  printInfo "Removing existing Liberty container"
  deleteContainer "${LIBERTY1_CONTAINER_NAME}"
}

function startLibertyContainer() {
  printInfo "Starting up new Liberty container"
  runLiberty "${LIBERTY1_CONTAINER_NAME}" "${I2_ANALYZE_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${HOST_PORT_I2ANALYZE_SERVICE}" "${I2_ANALYZE_CERT_FOLDER_NAME}" "${LIBERTY1_DEBUG_PORT}"
  updateLog4jFile
  addConfigAdmin
  checkLibertyStatus
}

function checkDataSetExists() {
  printInfo "Checking the data set ${DATA_SET} exists"
  local data_set_folder_path="${ROOT_DIR}/i2a-data/${DATA_SET}"
  if [[ ! -d "${data_set_folder_path}" ]]; then
    printErrorAndExit "${data_set_folder_path} does NOT exist"
  else
    printInfo "${data_set_folder_path} exist"
  fi
}

checkDeploymentIsLive "${CONFIG_NAME}"

if [[ "${TASK}" == "ingest" ]]; then
  checkDataSetExists
  runIngestionScript
elif [[ "${TASK}" == "delete" ]]; then
  removeLibertyContainer
  runClearData
  startLibertyContainer
elif [[ "${TASK}" == "sources" ]]; then
  createIngestionSources "${SCRIPT_NAME}"
fi