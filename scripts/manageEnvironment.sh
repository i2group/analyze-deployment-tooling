#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

echo "BASH_VERSION: $BASH_VERSION"
set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "This project should be run inside a VSCode Dev Container. For more information read, the Getting Started guide at https://i2group.github.io/analyze-containers/content/getting_started.html"
  exit 1
fi

function printUsage() {
  echo "Usage:"
  echo "  manageEnvironment.sh -t backup [-p <path>] [-i <config_name>] [-e <config_name>] [-b <backup_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t copy -p <path> [-i <config_name>] [-e <config_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t upgrade -p <path> [-y]" 1>&2
  echo "  manageEnvironment.sh -t update [-y]" 1>&2
  echo "  manageEnvironment.sh -t clean [-i <config_name>] [-e <config_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t connectors [-i <connector_name>] [-e <connector_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -t extensions [-i <extension_name>] [-e <extension_name>] [-y]" 1>&2
  echo "  manageEnvironment.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -t {backup}                                         Backup the database for a config." 1>&2
  echo "  -t {copy}                                           Copy the dependencies for a config from the specified path, to the current analyze-containers project." 1>&2
  echo "  -t {upgrade}                                        Upgrade all configurations from the specified path." 1>&2
  echo "  -t {update}                                         Update images." 1>&2
  echo "  -t {clean}                                          Clean the deployment for a config. Will permanently remove all containers and data." 1>&2
  echo "  -t {connectors}                                     Build all connector images." 1>&2
  echo "  -t {extensions}                                     Build all extensions." 1>&2
  echo "  -i <config_name|extension_name|connector_name>      Name of the config, connector or extension to include for the task. To specify multiple values, add additional -i options." 1>&2
  echo "  -e <config_name|extension_name|connector_name>      Name of the config, connector or extension to exclude for the task. To specify multiple values, add additional -e options." 1>&2
  echo "  -b <backup_name>                                    Name of the backup to create or restore. If not specified, the default backup is used." 1>&2
  echo "  -p <path>                                           Path to the root of an analyze-containers project. Defaults to the current project path." 1>&2
  echo "  -y                                                  Answer 'yes' to all prompts." 1>&2
  echo "  -v                                                  Verbose output." 1>&2
  echo "  -h                                                  Display the help." 1>&2
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
      INCLUDED_ASSETS+=("$OPTARG")
      ;;
    e)
      EXCLUDED_ASSETS+=("${OPTARG}")
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

  if [[ "${TASK}" != "backup" && "${TASK}" != "copy" && "${TASK}" != "upgrade" && "${TASK}" != "update" &&
    "${TASK}" != "connectors" && "${TASK}" != "extensions" && "${TASK}" != "clean" ]]; then
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

  if [[ "${INCLUDED_ASSETS[*]}" && "${EXCLUDED_ASSETS[*]}" ]]; then
    printErrorAndUsage "Incompatible options: Both (-i) and (-e) were specified." >&2
  fi

  if [[ "${INCLUDED_ASSETS[*]}" && "${EXCLUDED_ASSETS[*]}" ]]; then
    printErrorAndUsage "Incompatible options: Both (-i) and (-e) were specified." >&2
  fi

  if [[ "${INCLUDED_ASSETS[*]}" && "${EXCLUDED_ASSETS[*]}" ]]; then
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
  setDependenciesTagIfNecessary
}

function createBackup() {
  local current_config="false"
  CONFIG_NAME="$1"

  export ANALYZE_CONTAINERS_ROOT_DIR="${PREVIOUS_PROJECT_PATH}"
  unset I2A_DEPENDENCIES_IMAGES_TAG

  AWS_DEPLOY="false" # TODO: remove this when 2.1.3 is not supported for upgrade. Required to set EXTRA_ARGS
  source "${PREVIOUS_PROJECT_PATH}/utils/commonFunctions.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/clientFunctions.sh"
  source "${PREVIOUS_PROJECT_PATH}/configs/${CONFIG_NAME}/utils/variables.sh"
  source "${PREVIOUS_PROJECT_PATH}/configs/${CONFIG_NAME}/version"
  source "${PREVIOUS_PROJECT_PATH}/utils/simulatedExternalVariables.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/commonVariables.sh"
  source "${PREVIOUS_PROJECT_PATH}/utils/internalHelperVariables.sh"
  if [[ "${VERSION}" > "2.3.0" || "${VERSION}" == "2.3.0" ]]; then
    setDependenciesTagIfNecessary
  fi

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

  getVolume "${BACKUP_DIR}" "${SQL_SERVER_BACKUP_VOLUME_NAME}" "${DB_CONTAINER_BACKUP_DIR}"

  print "Stopping container: ${SQL_SERVER_CONTAINER_NAME}"
  stopContainer "${SQL_SERVER_CONTAINER_NAME}"
}

function createBackups() {
  for config_name in "${CONFIG_ARRAY[@]}"; do
    createBackup "${config_name}"
  done
}

function buildConfigArray() {
  CONFIG_ARRAY=()
  if [[ "${INCLUDED_ASSETS[*]}" ]]; then
    # if included configs provided assign them to the CONFIG_ARRAY
    CONFIG_ARRAY+=("${INCLUDED_ASSETS[@]}")
  else
    # All configs
    for config_dir in "${PREVIOUS_PROJECT_PATH}"/configs/*; do
      [[ ! -d "${config_dir}" ]] && continue
      config_name=$(basename "${config_dir}")
      CONFIG_ARRAY+=("${config_name}")
    done

    # All configs minus excluded configs
    if [[ -n "${EXCLUDED_ASSETS}" ]]; then
      for excluded_config in "${EXCLUDED_ASSETS[@]}"; do
        for i in "${!CONFIG_ARRAY[@]}"; do
          if [[ ${CONFIG_ARRAY[i]} == "${excluded_config}" ]]; then
            unset 'CONFIG_ARRAY[i]'
          fi
        done
      done
    fi
  fi
}

function buildConnectorsArray() {
  CONNECTORS_ARRAY=()
  if [[ "${INCLUDED_ASSETS[*]}" ]]; then
    # if included connectors provided assign them to the CONFIG_ARRAY
    CONNECTORS_ARRAY+=("${INCLUDED_ASSETS[@]}")
  else
    # All connectors
    for connector_dir in "${PREVIOUS_PROJECT_PATH}"/connector-images/*; do
      [[ ! -d "${connector_dir}" ]] && continue
      connector_name=$(basename "${connector_dir}")
      CONNECTORS_ARRAY+=("${connector_name}")
      echo ""
    done

    # All connectors minus excluded connectors
    if [[ -n "${EXCLUDED_ASSETS}" ]]; then
      for excluded_connector in "${EXCLUDED_ASSETS[@]}"; do
        for i in "${!CONNECTORS_ARRAY[@]}"; do
          if [[ ${CONNECTORS_ARRAY[i]} == "${excluded_connector}" ]]; then
            unset 'CONNECTORS_ARRAY[i]'
          fi
        done
      done
    fi
  fi
}

function buildExtensionsArray() {
  EXTENSIONS_ARRAY=()
  if [[ "${INCLUDED_ASSETS[*]}" ]]; then
    # if included extensions provided assign them to the CONFIG_ARRAY
    EXTENSIONS_ARRAY+=("${INCLUDED_ASSETS[@]}")
  else
    # All extensions extensions
    for extension_dir in "${PREVIOUS_PROJECT_PATH}"/i2a-extensions/*; do
      [[ ! -d "${extension_dir}" ]] && continue
      extension_name=$(basename "${extension_dir}")
      EXTENSIONS_ARRAY+=("${extension_name}")
    done

    # All extensions minus excluded extensions
    if [[ -n "${EXCLUDED_ASSETS}" ]]; then
      for excluded_extension in "${EXCLUDED_ASSETS[@]}"; do
        for i in "${!EXTENSIONS_ARRAY[@]}"; do
          if [[ ${EXTENSIONS_ARRAY[i]} == "${excluded_extension}" ]]; then
            unset 'EXTENSIONS_ARRAY[i]'
          fi
        done
      done
    fi

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

  if [[ -f "${PREVIOUS_PROJECT_PATH}/license.conf" ]]; then
    cp -pr "${PREVIOUS_PROJECT_PATH}/license.conf" "${CURRENT_PROJECT_PATH}/license.conf"
  fi

  source "${PREVIOUS_PROJECT_PATH}/version"

  for config_name in "${CONFIG_ARRAY[@]}"; do
    local prev_config_path="${PREVIOUS_PROJECT_PATH}/configs/${config_name}"
    local current_config_path="${CURRENT_PROJECT_PATH}/configs/${config_name}"
    [[ ! -d "${prev_config_path}" ]] && continue
    if [[ -d "${current_config_path}" ]]; then
      printErrorAndExitIfNecessary "Config folder already exists: ${current_config_path}"
    else
      cp -pr "${prev_config_path}" "${CURRENT_PROJECT_PATH}/configs"

      # Ensure the version file is present and upgraded
      if [[ ! -f "${current_config_path}/version" ]]; then
        cp "${CURRENT_PROJECT_PATH}/utils/templates/version" "${current_config_path}"
        if [[ "${VERSION}" < "2.3.0" ]]; then
          sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${I2ANALYZE_VERSION}/g" "${current_config_path}/version"
        else
          sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" "${current_config_path}/version"
        fi
      else
        # Rename variable
        sed -i -r "s/^I2ANALYZE_VERSION=(.*)/SUPPORTED_I2ANALYZE_VERSION=\1/g" "${current_config_path}/version"
      fi
      # Add prometheus config
      if [[ ! -d "${current_config_path}/configuration/prometheus" ]]; then
        createFolder "${current_config_path}/configuration/prometheus"
        cp -pr "${CURRENT_PROJECT_PATH}/templates/config-development/configuration/prometheus/"* "${current_config_path}/configuration/prometheus"
      fi
      # Add grafana config
      if [[ ! -d "${current_config_path}/configuration/grafana" ]]; then
        createFolder "${current_config_path}/configuration/grafana"
        cp -pr "${CURRENT_PROJECT_PATH}/templates/config-development/configuration/grafana/"* "${current_config_path}/configuration/grafana"
      fi
      # Add privacy agreement
      if [[ ! -f "${current_config_path}/configuration/privacyagreement.html" ]]; then
        cp -p "${CURRENT_PROJECT_PATH}/templates/config-development/configuration/privacyagreement.html" "${current_config_path}/configuration/privacyagreement.html"
      fi
      # Update HOST_PORT_PROMETHEUS to variables.sh
      if ! grep -q HOST_PORT_PROMETHEUS "${current_config_path}/utils/variables.sh"; then
        echo -e "\nHOST_PORT_PROMETHEUS=9090" >>"${current_config_path}/utils/variables.sh"
      fi
      # Update HOST_PORT_GRAFANA to variables.sh
      if ! grep -q HOST_PORT_GRAFANA "${current_config_path}/utils/variables.sh"; then
        echo -e "\nHOST_PORT_GRAFANA=3500" >>"${current_config_path}/utils/variables.sh"
      fi
    fi
  done

  if [[ -d "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration" ]]; then
    if [[ ! -f "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version" ]]; then
      cp "${CURRENT_PROJECT_PATH}/utils/templates/version" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration"
      if [[ "${VERSION}" < "2.3.0" ]]; then
        sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${I2ANALYZE_VERSION}/g" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version"
      else
        sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version"
      fi
    else
      # Rename variable
      sed -i -r "s/^I2ANALYZE_VERSION=(.*)/SUPPORTED_I2ANALYZE_VERSION=\1/g" "${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration/version"
    fi
  fi

  if [[ "${TASK}" == "upgrade" ]]; then
    local previous_pre_prod_config_path="${PREVIOUS_PROJECT_PATH}/examples/pre-prod/configuration"
    local current_pre_prod_config_path="${CURRENT_PROJECT_PATH}/examples/pre-prod/configuration"
    if [[ -d "${previous_pre_prod_config_path}" ]]; then
      deleteFolderIfExistsAndCreate "${current_pre_prod_config_path}"
      cp -pr "${previous_pre_prod_config_path}/"* "${current_pre_prod_config_path}"
      if [[ ! -f "${previous_pre_prod_config_path}/fragments/common/privacyagreement.html" ]]; then
        cp -p "${CURRENT_PROJECT_PATH}/pre-reqs/i2analyze/toolkit/examples/configurations/all-patterns/configuration/fragments/common/privacyagreement.html" "${current_pre_prod_config_path}/fragments/common/privacyagreement.html"
      fi
    fi
    local previous_pre_prod_generated_path="${PREVIOUS_PROJECT_PATH}/examples/pre-prod/database-scripts"
    local current_pre_prod_generated_path="${CURRENT_PROJECT_PATH}/examples/pre-prod/database-scripts"
    if [[ -d "${previous_pre_prod_generated_path}" ]]; then
      deleteFolderIfExistsAndCreate "${current_pre_prod_generated_path}"
      cp -pr "${previous_pre_prod_generated_path}/"* "${current_pre_prod_generated_path}"
    fi
  fi
  source "${CURRENT_PROJECT_PATH}/version"
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
      # Fix permissions
      sudo chown -R "$(id -u "${USER}")" "${backup_path}"
      cp -r "${backup_path}" "${CURRENT_PROJECT_PATH}/backups"
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

  printInfo "Generating missing secrets"
  "${CURRENT_PROJECT_PATH}/utils/generateSecrets.sh"

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

  # Reset to correct root
  export ANALYZE_CONTAINERS_ROOT_DIR="${CURRENT_PROJECT_PATH}"
  unset I2A_DEPENDENCIES_IMAGES_TAG
  sourceCommonVariablesAndScripts

  # Copy all
  copyConfigurations
  copyBackups
  copySecrets
  copyExtensions
  copyConnectors
  copyGatewaySchemas
  copyData

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
  done

  print "All configurations have been upgraded"
  waitForUserReply "The contents of ${PREVIOUS_PROJECT_PATH} will be removed and replaced with the contents of ${CURRENT_PROJECT_PATH}. Do you want to continue?"

  # cspell:ignore aqprkL
  rsync -aqprkL --exclude='dev' --delete "${ANALYZE_CONTAINERS_ROOT_DIR}/" "${PREVIOUS_PROJECT_PATH}"

  echo "Done"
  echo "Please delete ${CURRENT_PROJECT_PATH} and open ${PREVIOUS_PROJECT_PATH} in a new VSCode window."
}

function getImageId() {
  local image_name_and_version="$1"

  docker inspect --format "{{.Id}}" "${image_name_and_version}"
}

function getImageIds() {
  local image_ids

  image_ids+=$(getImageId "i2group/i2eng-zookeeper:${ZOOKEEPER_VERSION}")
  image_ids+=$(getImageId "i2group/i2eng-prometheus:${PROMETHEUS_VERSION}")
  image_ids+=$(getImageId "grafana/grafana-oss:${GRAFANA_VERSION}")
  image_ids+=$(getImageId "${LOAD_BALANCER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")
  image_ids+=$(getImageId "${LIBERTY_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")
  image_ids+=$(getImageId "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")
  image_ids+=$(getImageId "${SQL_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")
  image_ids+=$(getImageId "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")
  image_ids+=$(getImageId "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}")

  echo "${image_ids}"
}

function runUpdateTask() {
  setDependenciesTagIfNecessary

  PREVIOUS_IMAGE_IDS=$(getImageIds)

  print "Running buildImages.sh"
  "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildImages.sh"

  CURRENT_IMAGE_IDS=$(getImageIds)

  printInfo "PREVIOUS_IMAGE_IDS: ${PREVIOUS_IMAGE_IDS}"
  printInfo "CURRENT_IMAGE_IDS: ${CURRENT_IMAGE_IDS}"

  if [[ "${PREVIOUS_IMAGE_IDS}" == "${CURRENT_IMAGE_IDS}" ]]; then
    print "Your images are already up-to-date. You do NOT need to clean and redeploy your configs."
  else
    print "Your images have been updated. Use the deploy script to clean and redeploy your configs."
  fi
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

function runPruneTask() {
  waitForUserReply "Are you sure you want to run the 'prune' task? This will permanently remove data and images from the deployment."

  for config in "${PREVIOUS_PROJECT_PATH}"/configs/*; do
    if [[ ! -d "${config}" ]]; then
      continue
    fi

    CONFIG_NAME=$(basename "${config}")
    source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

    printInfo "Deleting previous configuration folder: ${PREVIOUS_CONFIGURATION_DIR}"
    deleteFolderIfExists "${PREVIOUS_CONFIGURATION_DIR}"
  done

  deleteAllContainers

  print "Removing all volumes"
  VOLUME_NAME_PREFIX=("zk" "solr" "sqlserver" "db2server" "liberty" "i2a_data" "load_balancer")

  for volume_prefix in "${VOLUME_NAME_PREFIX[@]}"; do
    readarray -t volumes < <(docker volume ls -q --filter "name=^${volume_prefix}" --format "{{.Name}}")
    if [[ "${#volumes[@]}" -ne 0 ]]; then
      docker volume rm "${volumes[@]}"
    fi
  done

  print "Removing all images"
  IMAGE_NAME_PREFIX=("zookeeper_" "solr_" "sqlserver_" "db2_" "liberty_" "etlclient_" "i2a_tools_" "ha_proxy_" "example_connector" "i2connect_sdk")

  for image_prefix in "${IMAGE_NAME_PREFIX[@]}"; do
    readarray -t images < <(docker image ls -q --filter "reference=${image_prefix}*" --format "{{.Repository}}:{{.Tag}}")
    if [[ "${#images[@]}" -ne 0 ]]; then
      docker rmi "${images[@]}"
    fi
  done
}

function runBuildConnectorsTask() {
  local connector_args=()

  buildConnectorsArray

  for connector in "${CONNECTORS_ARRAY[@]}"; do
    connector_args+=(-i "${connector}")
    deleteFileIfExists "${PREVIOUS_CONNECTOR_IMAGES_DIR}/${connector}.sha512"
  done

  if [[ "${YES_FLAG}" == "true" ]]; then
    connector_args+=("-y")
  fi

  if [[ "${VERBOSE}" == "true" ]]; then
    connector_args+=("-v")
  fi

  print "Running generateSecrets.sh"
  "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/generateSecrets.sh" -c connectors "${connector_args[@]}"
  print "Running buildConnectorImages.sh"
  "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildConnectorImages.sh" "${connector_args[@]}"
}

function runBuildExtensionsTask() {
  local extension_args=()

  buildExtensionsArray

  for extension in "${EXTENSIONS_ARRAY[@]}"; do
    extension_args+=(-i "${extension}")
    deleteFileIfExists "${PREVIOUS_EXTENSIONS_DIR}/${extension}.sha512"
  done

  if [[ "${YES_FLAG}" == "true" ]]; then
    extension_args+=("-y")
  fi

  if [[ "${VERBOSE}" == "true" ]]; then
    extension_args+=("-v")
  fi

  print "Building i2 Analyze extensions"
  "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildExtensions.sh" "${extension_args[@]}"
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
  update)
    runUpdateTask
    ;;
  connectors)
    runBuildConnectorsTask
    ;;
  extensions)
    runBuildExtensionsTask
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
checkDockerIsRunning
runTask
