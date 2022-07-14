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

function sourceCommonVariablesAndScripts() {
  # Load common functions
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

  # Load common variables
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
  else
    source "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/utils/variables.sh"
    source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
  fi
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"
}

function printUsage() {
  echo "Usage:"
  echo "  createChangeSet.sh -e {pre-prod|config-dev} -t {upgrade|update} [-c <config_name>] [-n <change_set_number>]"
  echo "  createChangeSet.sh -e pre-prod -t upgrade [-n <change_set_number>]"
  echo "  createChangeSet.sh -e config-dev -t {upgrade|update} [-n <change_set_number>]"
  echo "  createChangeSet.sh -h"
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:"
  echo "  -c <config_name>                       Name of the config to use." 1>&2
  echo "  -t <type>                              The type of the config-set." 1>&2
  echo "  -n <change_set_number>                 The number of config-set to be created." 1>&2
  echo "  -v                                     Verbose output." 1>&2
  echo "  -h                                     Display the help." 1>&2
  exit 1
}

function parseArguments() {
  while getopts "e:c:n:t:vh" flag; do
    case "${flag}" in
    e)
      ENVIRONMENT="${OPTARG}"
      ;;
    c)
      CONFIG_NAME="${OPTARG}"
      ;;
    t)
      TYPE="${OPTARG}"
      ;;
    n)
      CHANGE_SET_NUMBER="${OPTARG}"
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

function setDefaults() {
  AWS_DEPLOY="false"
  AWS_ARTIFACTS="false"
}

function nextChangeSetNumber() {
  local nextChangeSetNumber
  # shellcheck disable=SC2012
  if [[ -d ${CHANGE_SETS_DIR} && $(ls -A "${CHANGE_SETS_DIR}") ]]; then
    nextChangeSetNumber=$(ls "${CHANGE_SETS_DIR}" | sort -V | tail -n 1 | sed 's/-.*//')
    ((nextChangeSetNumber++))
    echo "${nextChangeSetNumber}"
  else
    echo "1"
  fi
}

function validateArguments() {
  if [[ -z "${ENVIRONMENT}" ]]; then
    usage
  fi
  [[ "${ENVIRONMENT}" == "pre-prod" || "${ENVIRONMENT}" == "config-dev" ]] || usage

  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    [[ "${TYPE}" == "upgrade" || "${TYPE}" == "update" ]] || usage
  else
    if [[ -z "${CONFIG_NAME}" ]]; then
      usage
    fi
    [[ "${TYPE}" == "upgrade" || "${TYPE}" == "update" ]] || usage
  fi
}

function setEnvironmentVariables() {
  local dir_name="${1:-${TYPE}}"

  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    CHANGE_SETS_DIR="${LOCAL_CHANGE_SETS_DIR}"
  else
    CHANGE_SETS_DIR="${LOCAL_USER_CHANGE_SETS_DIR}"
  fi

  if [[ -z "${CHANGE_SET_NUMBER}" ]]; then
    CHANGE_SET_NUMBER=$(nextChangeSetNumber)
  fi

  CHANGE_SET_DIR="${CHANGE_SETS_DIR}/${CHANGE_SET_NUMBER}-${dir_name}-$(date "+%Y.%m.%d-%H.%M")"

  CONFIG_CHANGE_SET_DIR="${CHANGE_SET_DIR}/configuration"
  DB_CHANGE_SET_DIR="${CHANGE_SET_DIR}/database-scripts/generated"

  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    CONFIG_DIR="${LOCAL_CONFIG_DIR}"
  else
    CONFIG_DIR="${LOCAL_USER_CONFIG_DIR}"
  fi

  FILES_TO_UPGRADE=(
    "InfoStoreNamesDb2.properties"
    "InfoStoreNamesSQLServer.properties"
    "DiscoSolrConfiguration.properties"
  )

  ALL_PATTERNS_CONFIG_DIR="${LOCAL_TOOLKIT_DIR}/examples/configurations/all-patterns/configuration"
}

function createChangeSetVersionFile() {
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    source "${LOCAL_CONFIG_DIR}/version"
  else
    source "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/version"
  fi
  CONFIG_I2ANALYZE_VERSION="${I2ANALYZE_VERSION}"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"
  CURRENT_I2ANALYZE_VERSION="${I2ANALYZE_VERSION}"
  echo -e "FROM_I2ANALYZE_VERSION=${CONFIG_I2ANALYZE_VERSION}\nTO_I2ANALYZE_VERSION=${CURRENT_I2ANALYZE_VERSION}" >"${CHANGE_SET_DIR}/version"
}

function createUpgradeChangeSet() {
  print "Creating Change-Set: ${CHANGE_SET_DIR}"

  createFolder "${CHANGE_SET_DIR}"

  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    createDatabaseUpgradeChangeSet
  fi
  createConfigurationUpgradeChangeSet

  if [[ ! $(ls -A "${CHANGE_SET_DIR}") ]]; then
    print "No upgrade changes detected"
    rm -r "${CHANGE_SET_DIR}"
  else
    createChangeSetVersionFile
  fi
}

function createUpdateChangeSet() {
  print "Creating Change-Set: ${CHANGE_SET_DIR}"
  createUpdateSchemaChangeSet
}

function createUpdateSchemaChangeSet() {
  local errors_message="Validation errors detected, please review the above message(s)"
  local db_update_dir="${DB_CHANGE_SET_DIR}/update"

  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    print "Validating the schema"
    if ! runi2AnalyzeTool "/opt/i2-tools/scripts/validateSchemaAndSecuritySchema.sh" >'/tmp/result_validate_security_schema'; then
      echo "[INFO] Response from i2 Analyze Tool: $(cat '/tmp/result_validate_security_schema')"
      # check i2 Analyze Tool for output indicating a Schema change has occurred, if so then prompt user for destructive
      # rebuild of ISTORE database.
      #
      # Note the error message from i2 Analyze is currently not great and incorrectly indicates that the 'Schema file
      # is not valid', what it really means is its not valid for the current deployment and thus must be re-deployed via
      # a destructive change to the ISTORE database.
      if grep -q 'ERROR: The new Schema file is not valid, see the summary for more details.' '/tmp/result_validate_security_schema'; then
        echo "[WARN] Destructive Schema change(s) detected"
        setEnvironmentVariables "reset"

        runi2AnalyzeTool "/opt/i2-tools/scripts/generateInfoStoreToolScripts.sh"
        runi2AnalyzeTool "/opt/i2-tools/scripts/generateStaticInfoStoreCreationScripts.sh"
        runi2AnalyzeTool "/opt/i2-tools/scripts/generateDynamicInfoStoreCreationScripts.sh"

        createFolder "${DB_CHANGE_SET_DIR}/static"
        createFolder "${DB_CHANGE_SET_DIR}/dynamic"

        cp "${LOCAL_GENERATED_DIR}/static/"* "${DB_CHANGE_SET_DIR}/static"
        cp "${LOCAL_GENERATED_DIR}/dynamic/"* "${DB_CHANGE_SET_DIR}/dynamic"

        createFolder "${CONFIG_CHANGE_SET_DIR}"
        cp "${CONFIG_DIR}/schema.xml" "${CONFIG_CHANGE_SET_DIR}"
      else
        printErrorAndExit "[INFO] Response from i2 Analyze Tool: $(cat '/tmp/result_validate_security_schema')"
      fi
    else
      deleteFolderIfExists "${LOCAL_GENERATED_DIR}/update"

      print "Generating update schema scripts"
      runi2AnalyzeTool "/opt/i2-tools/scripts/generateUpdateSchemaScripts.sh"
      if [ -d "${LOCAL_GENERATED_DIR}/update" ]; then
        if [ "$(ls -A "${LOCAL_GENERATED_DIR}/update")" ]; then
          createFolder "${db_update_dir}"
          cp "${LOCAL_GENERATED_DIR}/update/"* "${db_update_dir}"
          for file in "${db_update_dir}/"*; do
            if [[ ! -s "${file}" ]]; then
              rm "${file}"
            fi
          done
          createFolder "${CONFIG_CHANGE_SET_DIR}"
          cp "${CONFIG_DIR}/schema.xml" "${CONFIG_CHANGE_SET_DIR}"
        else
          printInfo "No files present in update schema scripts folder"
        fi
      else
        printInfo "Update schema scripts folder doesn't exist"
      fi
    fi
  fi
}

function createChangeSet() {
  if [[ "${TYPE}" == "upgrade" ]]; then
    createUpgradeChangeSet
  elif [[ "${TYPE}" == "update" ]]; then
    createUpdateChangeSet
  fi
}

function createDatabaseUpgradeChangeSet() {
  local db_upgrade_dir="${DB_CHANGE_SET_DIR}/upgrade"

  print "Generating Database Upgrade Change-Set"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateInfoStoreToolScripts.sh"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateStaticInfoStoreCreationScripts.sh"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateDynamicInfoStoreCreationScripts.sh"

  find "${LOCAL_GENERATED_DIR}/static/" -type f -maxdepth 1 -exec cp {} "${LOCAL_GENERATED_DIR}" \;
  mkdir -p "${LOCAL_GENERATED_DIR}/upgrade"
  cp "${LOCAL_GENERATED_DIR}/static/2020-create-deletion-by-rule-routines.sql" "${LOCAL_GENERATED_DIR}/upgrade"

  runi2AnalyzeTool "/opt/i2-tools/scripts/generateDatabaseUpgradeScripts.sh"

  if [[ -d "${LOCAL_GENERATED_DIR}/upgrade" && $(ls -A "${LOCAL_GENERATED_DIR}/upgrade") ]]; then
    createFolder "${db_upgrade_dir}"
    cp "${LOCAL_GENERATED_DIR}/upgrade/"* "${db_upgrade_dir}"
    for file in "${db_upgrade_dir}/"*; do
      [[ -s "${file}" ]] || rm "${file}"
    done
  else
    echo "Database is already at the latest version"
  fi
}

function check_collection_exists() {
  local collection="$1"
  local json
  json=$(runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/${collection}/admin/ping\"")
  if jq -e . >/dev/null 2>&1 <<<"$json"; then
    status=$(echo "$json" | jq -r ".status")
    [[ "${status}" == "OK" ]] && echo "true" || echo "false"
  else
    echo "false"
  fi
}

function createConfigurationUpgradeChangeSet() {
  print "Generating Configuration Upgrade Change-Set"

  declare -A properties
  local files_upgraded=()
  local filepath
  # Liberty
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    deleteFolderIfExistsAndCreate "${PRE_PROD_DIR}/.configuration_old"
    cp -Rp "${CONFIG_DIR}/." "${PRE_PROD_DIR}/.configuration_old"
    "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createConfiguration.sh" -e "${ENVIRONMENT}"
    deleteFolderIfExistsAndCreate "${PRE_PROD_DIR}/.configuration_new"
    cp -Rp "${CONFIG_DIR}/." "${PRE_PROD_DIR}/.configuration_new"
    deleteFolderIfExistsAndCreate "${CONFIG_DIR}"
    cp -Rp "${PRE_PROD_DIR}/.configuration_old/." "${CONFIG_DIR}"

    for file in "${FILES_TO_UPGRADE[@]}"; do
      filepath=$(find "${CONFIG_DIR}" -type f -name "${file}" -print0 | xargs)

      checksumPrevious=$(shasum -a 256 "${PRE_PROD_DIR}/.configuration_new/${filepath//${CONFIG_DIR}/}" | cut -d ' ' -f 1)
      checksumCurrent=$(shasum -a 256 "${filepath}" | cut -d ' ' -f 1)
      # if checksums different then add to changeset
      if [[ "$checksumPrevious" != "$checksumCurrent" ]]; then
        printInfo "Adding changed file to changeset: ${file}"
        mkdir -p "$(dirname "${CONFIG_CHANGE_SET_DIR}/${filepath//${CONFIG_DIR}/}")"
        cp -Rp "${PRE_PROD_DIR}/.configuration_new/${filepath//${CONFIG_DIR}/}" "${CONFIG_CHANGE_SET_DIR}/${filepath//${CONFIG_DIR}/}"
        cp -Rp "${PRE_PROD_DIR}/.configuration_new/${filepath//${CONFIG_DIR}/}" "${filepath}"
      fi
    done

    rm -R "${PRE_PROD_DIR}/.configuration_old" "${PRE_PROD_DIR}/.configuration_new"
  else
    for file in "${FILES_TO_UPGRADE[@]}"; do
      properties=()
      while IFS= read -r line; do
        [[ "${line}" =~ ^#.* ]] && continue
        [[ -z "${line}" ]] && continue
        properties["${line%%=*}"]="${line#*=}"
      done <"${LOCAL_CONFIG_DEV_DIR}/configuration/${file}"

      # Add empty new line if none
      if [[ -n "$(tail -c1 "${CONFIG_DIR}/${file}")" ]]; then
        echo >>"${CONFIG_DIR}/${file}"
      fi
      for prop in "${!properties[@]}"; do
        if grep -q -E -o -m 1 "${prop}" <"${CONFIG_DIR}/${file}"; then
          continue
        fi
        echo "${prop}=${properties["${prop}"]}" >>"${CONFIG_DIR}/${file}"

        # shellcheck disable=SC2076
        if [[ ! " ${files_upgraded[*]} " =~ " ${CONFIG_DIR}/${file} " ]]; then
          files_upgraded+=("${CONFIG_DIR}/${file}")
        fi
      done
    done
    for file in "${files_upgraded[@]}"; do
      filepath="${file//"${CONFIG_DIR}/"/}"
      printInfo "Adding changed file to changeset: ${filepath}"
      mkdir -p "$(dirname "${CONFIG_CHANGE_SET_DIR}/${filepath}")"
      cp -Rp "${file}" "${CONFIG_CHANGE_SET_DIR}/${filepath}"
    done
  fi

  # Solr
  deleteFolderIfExistsAndCreate "${CONFIG_DIR}/solr/.generated_config"
  cp -Rp "${CONFIG_DIR}/solr/generated_config/." "${CONFIG_DIR}/solr/.generated_config"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateSolrSchemas.sh"
  if [[ "${ENVIRONMENT}" != "pre-prod" ]]; then
    # in pre-prod they are the same
    cp -Rp "${LOCAL_CONFIG_DIR}/solr/generated_config" "${CONFIG_DIR}/solr"
  fi

  for file in "${CONFIG_DIR}/solr/generated_config/"* "${CONFIG_DIR}/solr/generated_config/"**/*; do
    [[ ! -f "${file}" ]] && continue
    filepath="${file//"${CONFIG_DIR}/solr/generated_config/"/}"
    if [[ ! -f "${CONFIG_DIR}/solr/.generated_config/${filepath}" ]]; then
      printInfo "Adding new file to changeset: ${filepath}"
      mkdir -p "$(dirname "${CONFIG_DIR}/solr/.generated_config/${filepath}")"
      cp -Rp "${file}" "${CONFIG_DIR}/solr/.generated_config/${filepath}"
      continue
    fi

    checksumPrevious=$(shasum -a 256 "${CONFIG_DIR}/solr/.generated_config/${filepath}" | cut -d ' ' -f 1)
    checksumCurrent=$(shasum -a 256 "${file}" | cut -d ' ' -f 1)
    # if checksums different then new config otherwise delete from changeset
    if [[ "$checksumPrevious" == "$checksumCurrent" ]]; then
      printInfo "Deleting non-changed file from changeset: ${filepath}"
      rm "${CONFIG_DIR}/solr/.generated_config/${filepath}"
    else
      printInfo "Adding changed file to changeset: ${filepath}"
      mkdir -p "$(dirname "${CONFIG_DIR}/solr/.generated_config/${filepath}")"
      cp -Rp "${file}" "${CONFIG_DIR}/solr/.generated_config/${filepath}"
    fi
  done

  if [[ $(find "${CONFIG_DIR}/solr/.generated_config" -type f -print0 | xargs) ]]; then
    find "${CONFIG_DIR}/solr/.generated_config/" -empty -type d -delete
    createFolder "${CONFIG_CHANGE_SET_DIR}/solr/generated_config"
    cp -Rp "${CONFIG_DIR}/solr/.generated_config/." "${CONFIG_CHANGE_SET_DIR}/solr/generated_config"
  else
    echo "Solr configuration is already at the latest version"
  fi
  rm -R "${CONFIG_DIR}/solr/.generated_config"
}

parseArguments "$@"
setDefaults
sourceCommonVariablesAndScripts
validateArguments
setEnvironmentVariables
createChangeSet
