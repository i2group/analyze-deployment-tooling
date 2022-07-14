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

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "Please run '. initShell.sh' in your terminal first or set it with 'export ANALYZE_CONTAINERS_ROOT_DIR=<path_to_root>'"
  exit 1
fi

function printUsage() {
  echo "Usage:"
  echo "  manageEnvironment.sh -t backup [-b <backup_name>] [-p <path>] [-i <config_name>] [-e <config_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t copy -p <path> [-i <config_name>] [-e <config_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t upgrade -p <path> [-y]" 1>&2
  echo "  manageEnvironment.sh -t clean [-i <config_name>] [-e <config_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -t {backup}                     Backup the database for a config." 1>&2
  echo "  -t {copy}                       Copy the dependencies for a config from the specified path, to the current analyze-containers project." 1>&2
  echo "  -t {upgrade}                    Upgrade all configurations from the specified path." 1>&2
  echo "  -t {clean}                      Clean the deployment for a config. Will permanently remove all containers and data." 1>&2
  echo "  -i <config_name>                Name of the config to include for the task. If no config is specified, the task acts on all configs. To specify multiple configs, add additional -i options." 1>&2
  echo "  -e <config_name>                Name of the config to exclude for the task. If no config is specified, the task acts on all configs. To specify multiple configs, add additional -e options." 1>&2
  echo "  -b <backup_name>                Name of the backup to create or restore. If not specified, the default backup is used." 1>&2
  echo "  -p <path>                       Path to the root of an analyze-containers project. Defaults to the current project path." 1>&2
  echo "  -y                              Answer 'yes' to all prompts." 1>&2
  echo "  -v                              Verbose output." 1>&2
  echo "  -h                              Display the help." 1>&2
  exit 1
}

function parseArguments() {
  while getopts ":t:i:e:p:b:yvh" flag; do
    case "${flag}" in
    t)
      TASK="${OPTARG}"
      ;;
    b)
      BACKUP_NAME="${OPTARG}"
      ;;
    i)
      INCLUDED_CONFIGS+=("$OPTARG")
      ;;
    e)
      EXCLUDED_CONFIGS+=("${OPTARG}")
      ;;
    p)
      PREVIOUS_PROJECT_PATH="${OPTARG}"
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
}

function printErrorAndUsage() {
  local error_message="$1"

  printError "${error_message}"
  usage
}

function printErrorAndExitIfNecessary() {
  local error_message="$1"

  printError "${error_message}"
  if [[ "${TASK}" == "upgrade" ]]; then
    exit 1
  fi
}

function validateArguments() {
  if [[ -z "${TASK}" ]]; then
    printErrorAndUsage "Task is not set."
  fi

  if [[ "${TASK}" != "backup" && "${TASK}" != "copy" && "${TASK}" != "upgrade" && "${TASK}" != "clean" ]]; then
    printErrorAndUsage "${TASK} is not supported."
  fi

  if [[ -z "${PREVIOUS_PROJECT_PATH}" ]]; then
    if [[ "${TASK}" == "copy" || "${TASK}" == "upgrade" ]]; then
      printErrorAndUsage "The path to an analyze-containers project must be set."
    fi
    PREVIOUS_PROJECT_PATH="${ANALYZE_CONTAINERS_ROOT_DIR}"
  elif [[ ! -d "${PREVIOUS_PROJECT_PATH}" ]]; then
    printErrorAndUsage "Directory doesn't exist: ${PREVIOUS_PROJECT_PATH}"
  fi
  CURRENT_PROJECT_PATH="${ANALYZE_CONTAINERS_ROOT_DIR}"

  if [[ "${INCLUDED_CONFIGS[*]}" && "${EXCLUDED_CONFIGS[*]}" ]]; then
    printErrorAndUsage "Incompatible options: Both (-i) and (-e) were specified." >&2
  fi
}

function setDefaults() {
  if [[ -z "${BACKUP_NAME}" ]]; then
    if [[ "${TASK}" == "backup" ]]; then
      BACKUP_NAME="global-backup"
    else
      BACKUP_NAME="global-upgrade"
    fi
  fi
  AWS_DEPLOY="false"
}

function sourceCommonVariablesAndScripts() {
  # Load common functions
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

  # Load common variables
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

  warnRootDirNotInPath
}

function createBackup() {
  local current_config="false"
  CONFIG_NAME="$1"

  export ANALYZE_CONTAINERS_ROOT_DIR="${PREVIOUS_PROJECT_PATH}"

  pushd "${PREVIOUS_PROJECT_PATH}"
  source "${PREVIOUS_PROJECT_PATH}/utils/commonFunctions.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/clientFunctions.sh"
  source "${PREVIOUS_PROJECT_PATH}/configs/${CONFIG_NAME}/utils/variables.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/simulatedExternalVariables.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/commonVariables.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/internalHelperVariables.sh"
  popd

  if [[ "${DEPLOYMENT_PATTERN}" != *"store"* ]]; then
    # Cannot print and exit since this is done for <all> configs and we want it to continue
    echo "${CONFIG_NAME} does not contain an ISTORE database to backup. It uses the ${DEPLOYMENT_PATTERN} deployment pattern."
    return
  fi

  if [[ "${DB_DIALECT}" == "db2" ]]; then
    printErrorAndExitIfNecessary "Db2 backup in not implemented yet"
    return
  fi

  print "Creating backup for: ${CONFIG_NAME}"

  local container_id
  container_id="$(docker ps -aq --no-trunc -f name="^${SQL_SERVER_CONTAINER_NAME}$")"

  if [[ -z "${container_id}" ]]; then
    printErrorAndExit "Cannot find the SQL Server container for config: ${CONFIG_NAME}. Please redeploy before running this task again."
  fi

  # Restart Docker containers
  print "Restarting container: ${SQL_SERVER_CONTAINER_NAME}"
  docker start "${SQL_SERVER_CONTAINER_NAME}"
  waitForSQLServerToBeLive

  if [[ -d "${PREVIOUS_PROJECT_PATH}/backups/${CONFIG_NAME}/${BACKUP_NAME}" ]]; then
    echo "There is already a backup for ${CONFIG_NAME} config with the name ${BACKUP_NAME}."
    if [[ "${TASK}" == "backup" ]]; then
      echo "You can run the command again and specify a different backup name by using the -b argument."
    fi
    waitForUserReply "Do you want to override the existing backup?"
  fi

  deleteFolderIfExistsAndCreate "${PREVIOUS_PROJECT_PATH}/backups/${CONFIG_NAME}/${BACKUP_NAME}"

  # Create the back up
  print "Backing up the ISTORE database for container: ${SQL_SERVER_CONTAINER_NAME}"

  local backup_file_path="${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}/${DB_BACKUP_FILE_NAME}"
  local sql_query="\
  	USE ISTORE;
  		BACKUP DATABASE ISTORE
  		TO DISK = '${backup_file_path}'
  		WITH FORMAT;"
  runSQLServerCommandAsDBB runSQLQuery "${sql_query}"

  # Update backup file permission to your local user
  docker exec "${SQL_SERVER_CONTAINER_NAME}" bash -c "chown -R $(id -u "${USER}"):$(id -g "${USER}") ${DB_CONTAINER_BACKUP_DIR}"

  getVolume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"

  print "Stopping container: ${SQL_SERVER_CONTAINER_NAME}"
  stopContainer "${SQL_SERVER_CONTAINER_NAME}"
}

function createBackups() {
  I2A_DEPENDENCIES_IMAGES_TAG="latest"
  for config_name in "${CONFIG_ARRAY[@]}"; do
    createBackup "${config_name}"
  done
  unset I2A_DEPENDENCIES_IMAGES_TAG
  setDependenciesTagIfNecessary
}

function buildConfigArray() {
  CONFIG_ARRAY=()
  if [[ "${INCLUDED_CONFIGS[*]}" ]]; then
    # if included configs provided assign them to the CONFIG_ARRAY
    CONFIG_ARRAY+=("${INCLUDED_CONFIGS[@]}")
  else
    for config in "${PREVIOUS_PROJECT_PATH}"/configs/*; do
      if [[ ! -d "${config}" ]]; then
        continue
      fi
      config_name=$(basename "${config}")
      if [[ "${EXCLUDED_CONFIGS[*]}" != *"${config_name}"* ]]; then
        # if excluded configs provided and it is a valid config name don't add it to the CONFIG_ARRAY
        CONFIG_ARRAY+=("${config_name}")
      fi
    done
  fi
}

function runBackupTask() {
  stopConfigDevContainers
  stopConnectorContainers
  buildConfigArray
  createBackups
}

function copyConfigurations() {
  print "Copying configs"

  for config_name in "${CONFIG_ARRAY[@]}"; do
    local config_path="${PREVIOUS_PROJECT_PATH}/configs/${config_name}"
    [[ ! -d "${config_path}" ]] && continue
    if [[ -d "${CURRENT_PROJECT_PATH}/configs/${config_name}" ]]; then
      printErrorAndExitIfNecessary "Config folder already exists: ${CURRENT_PROJECT_PATH}/configs/${config_name}"
    else
      cp -pr "${config_path}" "${CURRENT_PROJECT_PATH}/configs"
    fi
  done

  if [[ "${TASK}" == "upgrade" ]]; then
    local previous_pre_prod_config_path="${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration"
    local current_pre_prod_config_path="${CURRENT_PROJECT_PATH}/examples/pre-prod/configuration"
    if [[ -d "${previous_pre_prod_config_path}" ]]; then
      deleteFolderIfExistsAndCreate "${current_pre_prod_config_path}"
      cp -pr "${previous_pre_prod_config_path}/"* "${current_pre_prod_config_path}"
    fi
    local previous_pre_prod_generated_path="${PREVIOUS_PROJECT_PATH}/examples/pre-prod/database-scripts"
    local current_pre_prod_generated_path="${CURRENT_PROJECT_PATH}/examples/pre-prod/database-scripts"
    if [[ -d "${previous_pre_prod_generated_path}" ]]; then
      deleteFolderIfExistsAndCreate "${current_pre_prod_generated_path}"
      cp -pr "${previous_pre_prod_generated_path}/"* "${current_pre_prod_generated_path}"
    fi
  fi
}

function copyBackups() {
  local backup_path
  print "Copying backups"

  for backup_name in "${CONFIG_ARRAY[@]}"; do
    backup_path="${PREVIOUS_PROJECT_PATH}/backups/${backup_name}"
    [[ ! -d "${backup_path}" ]] && continue
    if [[ -d "${CURRENT_PROJECT_PATH}/backups/${backup_name}" ]]; then
      printErrorAndExitIfNecessary "Backup folder already exists: ${CURRENT_PROJECT_PATH}/backups/${backup_name}"
    else
      cp -pr "${backup_path}" "${CURRENT_PROJECT_PATH}/backups"
    fi
  done
}

function copyExtensions() {
  local extension_name
  print "Copying all extensions"

  for extension in "${PREVIOUS_PROJECT_PATH}"/i2a-extensions/*; do
    [[ ! -d "${extension}" ]] && continue
    extension_name=$(basename "${extension}")
    if [[ -d "${CURRENT_PROJECT_PATH}/i2a-extensions/${extension_name}" ]]; then
      printErrorAndExitIfNecessary "Extension already exists: ${CURRENT_PROJECT_PATH}/i2a-extensions/${extension_name}"
    else
      cp -pr "${extension}" "${CURRENT_PROJECT_PATH}/i2a-extensions"
    fi
  done
}

function copySecrets() {
  local secret_name
  print "Copying all secrets"

  for secret in "${PREVIOUS_PROJECT_PATH}"/dev-environment-secrets/*; do
    [[ ! -d "${secret}" ]] && continue
    secret_name=$(basename "${secret}")
    if [[ -d "${CURRENT_PROJECT_PATH}/dev-environment-secrets/${secret_name}" ]]; then
      rm -r "${CURRENT_PROJECT_PATH}/dev-environment-secrets/${secret_name}"
    fi
    cp -pr "${secret}" "${CURRENT_PROJECT_PATH}/dev-environment-secrets"
  done
  updateCoreSecretsVolumes
}

function copyConnectors() {
  local connector_name
  print "Copying all connector images"

  for connector in "${PREVIOUS_PROJECT_PATH}"/connector-images/*; do
    [[ ! -d "${connector}" ]] && continue
    connector_name=$(basename "${connector}")
    if [[ -d "${CURRENT_PROJECT_PATH}/connector-images/${connector_name}" ]]; then
      printErrorAndExitIfNecessary "Connector image folder already exists: ${CURRENT_PROJECT_PATH}/connector-images/${connector_name}"
    else
      cp -pr "${connector}" "${CURRENT_PROJECT_PATH}/connector-images"
    fi
  done
}

function copyData() {
  local data_set_name
  print "Copying all data sets"

  for data_set in "${PREVIOUS_PROJECT_PATH}"/i2a-data/*; do
    [[ ! -d "${data_set}" ]] && continue
    data_set_name=$(basename "${data_set}")
    if [[ -d "${CURRENT_PROJECT_PATH}/i2a-data/${data_set_name}" ]]; then
      printErrorAndExitIfNecessary "Data set folder already exists: ${CURRENT_PROJECT_PATH}/i2a-data/${data_set_name}"
    else
      cp -pr "${data_set}" "${CURRENT_PROJECT_PATH}/i2a-data"
    fi
  done
}

function copyGatewaySchemas() {
  local gateway_schema_name
  print "Copying all gateway schemas"

  for gateway_schema in "${PREVIOUS_PROJECT_PATH}"/gateway-schemas/*; do
    [[ ! -f "${gateway_schema}" ]] && continue
    gateway_schema_name=$(basename "${gateway_schema}")
    if [[ -f "${CURRENT_PROJECT_PATH}/gateway-schemas/${gateway_schema_name}" ]]; then
      printErrorAndExitIfNecessary "Gateway Schema already exists: ${CURRENT_PROJECT_PATH}/gateway-schemas/${gateway_schema_name}"
    else
      cp -pr "${gateway_schema}" "${CURRENT_PROJECT_PATH}/gateway-schemas/"
    fi
  done
}

function runCopyTask() {
  buildConfigArray
  copyConfigurations
  copyBackups
  copySecrets
  copyExtensions
  copyConnectors
  copyGatewaySchemas
  copyData
}

function runUpgradeTask() {
  # Prepare
  stopConfigDevContainers
  stopConnectorContainers
  buildConfigArray

  # Backup all
  createBackups

  source "${PREVIOUS_PROJECT_PATH}/version"

  # Ensure the version file is in all configs
  for config in "${PREVIOUS_PROJECT_PATH}"/configs/*; do
    if [[ ! -d "${config}" ]]; then
      continue
    fi
    config_name=$(basename "${config}")
    if [[ ! -f "${config}/version" ]]; then
      cp "${CURRENT_PROJECT_PATH}/utils/templates/version" "${config}"
      sed -i "s/I2ANALYZE_VERSION=.*/I2ANALYZE_VERSION=${I2ANALYZE_VERSION}/g" "${config}/version"
    fi
  done
  if [[ -d "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration" && ! -f "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version" ]]; then
    cp "${CURRENT_PROJECT_PATH}/utils/templates/version" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration"
    sed -i "s/I2ANALYZE_VERSION=.*/I2ANALYZE_VERSION=${I2ANALYZE_VERSION}/g" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version"
  fi

  # Copy all
  copyConfigurations
  copyBackups
  copySecrets
  copyExtensions
  copyConnectors
  copyGatewaySchemas
  copyData

  # Reset to correct root
  export ANALYZE_CONTAINERS_ROOT_DIR="${CURRENT_PROJECT_PATH}"
  unset I2A_DEPENDENCIES_IMAGES_TAG
  sourceCommonVariablesAndScripts

  # Upgrade
  extra_args=()
  if [[ "${YES_FLAG}" == "true" ]]; then
    extra_args+=("-y")
  fi
  if [[ "${VERBOSE}" == "true" ]]; then
    extra_args+=("-v")
  fi
  for config_name in "${CONFIG_ARRAY[@]}"; do
    stopConfigDevContainers
    stopConnectorContainers
    "${ANALYZE_CONTAINERS_ROOT_DIR}/scripts/deploy.sh" -c "${config_name}" "${extra_args[@]}"
    "${ANALYZE_CONTAINERS_ROOT_DIR}/scripts/deploy.sh" -c "${config_name}" -t "restore" -b "${BACKUP_NAME}" "${extra_args[@]}"
  done

  print "All configurations have been upgraded"
  waitForUserReply "The contents of ${PREVIOUS_PROJECT_PATH} will be removed and replaced with the contents of ${CURRENT_PROJECT_PATH}. Do you want to continue?"

  # cspell:ignore aqprkL
  rsync -aqprkL --exclude='dev' --delete "${ANALYZE_CONTAINERS_ROOT_DIR}/" "${PREVIOUS_PROJECT_PATH}"

  echo "Done"
  echo "Please delete ${CURRENT_PROJECT_PATH} and run '. initShell.sh' before continuing."
}

function cleanDeployment() {
  CONFIG_NAME="$1"

  source "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/version"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/utils/variables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

  local all_container_ids
  IFS=' ' read -ra all_container_ids <<<"$(docker ps -aq -f network="${DOMAIN_NAME}" -f name=".${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}$" | xargs)"
  print "Deleting all containers for ${CONFIG_NAME} deployment"
  for container_id in "${all_container_ids[@]}"; do
    printInfo "Deleting container ${container_id}"
    deleteContainer "${container_id}"
  done

  removeDockerVolumes

  printInfo "Deleting deployed extensions: ${LOCAL_LIB_DIR}"
  deleteFolderIfExists "${LOCAL_LIB_DIR}"

  printInfo "Deleting previous configuration folder: ${PREVIOUS_CONFIGURATION_DIR}"
  deleteFolderIfExists "${PREVIOUS_CONFIGURATION_DIR}"
}

function runCleanTask() {
  waitForUserReply "Are you sure you want to run the 'clean' task? This will permanently remove data from the deployment."
  buildConfigArray

  for config_name in "${CONFIG_ARRAY[@]}"; do
    cleanDeployment "${config_name}"
  done

  echo "Done"
}

function runTask() {
  case "${TASK}" in
  backup)
    runBackupTask
    ;;
  copy)
    runCopyTask
    ;;
  upgrade)
    runUpgradeTask
    ;;
  clean)
    runCleanTask
    ;;
  esac
}

sourceCommonVariablesAndScripts
parseArguments "$@"
validateArguments
setDefaults
runTask
