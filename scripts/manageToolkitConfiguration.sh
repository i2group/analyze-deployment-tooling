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

###############################################################################
# Function Definitions                                                        #
###############################################################################

function setDefaults() {
  # Local variables
  ON_PREM_CONFIG_DIR="${ON_PREM_TOOLKIT_DIR}/configuration"
  ENVIRONMENT_DIR="${ON_PREM_CONFIG_DIR}/environment"
  EXAMPLES_CONFIGS_DIR="${ON_PREM_TOOLKIT_DIR}/examples/configurations"
  FRAGMENTS_DIR="${ON_PREM_CONFIG_DIR}/fragments"
  COMMON_CLASSES_DIR="${FRAGMENTS_DIR}/common/WEB-INF/classes"
  OPAL_SERVICES_CLASSES_DIR="${FRAGMENTS_DIR}/opal-services/WEB-INF/classes"
  OPAL_SERVICES_IS_CLASSES_DIR="${FRAGMENTS_DIR}/opal-services-is/WEB-INF/classes"
  LIVE_DIR="${ON_PREM_CONFIG_DIR}/live"

  REQUIRED_COMMON_FIXED_FILE_NAMES=("${COMMON_CLASSES_DIR}/schema.xml"
    "${COMMON_CLASSES_DIR}/schema-charting-schemes.xml"
    "${COMMON_CLASSES_DIR}/security-schema.xml"
    "${COMMON_CLASSES_DIR}/mapping-configuration.json"
    "${OPAL_SERVICES_CLASSES_DIR}/command-access-control.xml"
    "${OPAL_SERVICES_CLASSES_DIR}/schema-vq-configuration.xml"
    "${OPAL_SERVICES_CLASSES_DIR}/schema-results-configuration.xml"
    "${OPAL_SERVICES_CLASSES_DIR}/schema-source-reference-schema.xml"
    "${LIVE_DIR}/fmr-match-rules.xml"
    "${LIVE_DIR}/geospatial-configuration.json"
    "${LIVE_DIR}/type-access-configuration.xml"
  )

  REQUIRED_FRAGMENTS_FOR_ANALYZE_SETTINGS_FILE_NAMES=("${COMMON_CLASSES_DIR}/analyze-settings.properties"
    "${COMMON_CLASSES_DIR}/analyze-connect.properties"
    "${COMMON_CLASSES_DIR}/ApolloServerSettingsConfigurationSet.properties"
    "${COMMON_CLASSES_DIR}/ApolloServerSettingsMandatory.properties"
  )

  REQUIRED_FRAGMENTS_FOR_ISTORE_DEPLOYMENT_FILE_NAMES=("${OPAL_SERVICES_IS_CLASSES_DIR}/InfoStoreNamesDb2.properties"
    "${OPAL_SERVICES_IS_CLASSES_DIR}/InfoStoreNamesSQLServer.properties"
    "${LIVE_DIR}/highlight-queries-configuration.xml"
    "${ENVIRONMENT_DIR}/system-match-rules.xml"
  )

  REQUIRED_FRAGMENTS_FOR_I2C_DEPLOYMENT_FILE_NAMES=("${LIVE_DIR}/system-match-rules.xml")

  IGNORED_FIXED_FILE_NAMES=(
    "${COMMON_CLASSES_DIR}/log4j2.xml"
    "${OPAL_SERVICES_IS_CLASSES_DIR}/catalog.json"
  )

  declare -gA FIXED_PROPERTIES
  FIXED_PROPERTIES=(
    ["SchemaResource"]=schema.xml
    ["ChartingSchemesResource"]=schema-charting-schemes.xml
    ["DynamicSecuritySchemaResource"]=security-schema.xml
    ["ResultsConfigurationResource"]=schema-results-configuration.xml
    ["CommandAccessControlResource"]=command-access-control.xml
    ["SourceReferenceSchemaResource"]=schema-source-reference-schema.xml
    ["VisualQueryConfigurationResource"]=schema-vq-configuration.xml
    ["TypeMappingResource"]=mapping-configuration.json
  )

  REQUIRED_ON_PREM_TOOLKIT_DIRS=(
    "application"
    "bin"
    "examples"
    "scripts"
    "scripts-bin"
    "tools"
  )
}

function printUsage() {
  echo "Usage:"
  echo "  manageToolkitConfiguration.sh -c <config_name> -p <toolkit_path> -t { create | prepare | import | export } [-v]"
  echo "  manageToolkitConfiguration.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -c <config_name>             Name of the config to use." 1>&2
  echo "  -p <toolkit_path>            The absolute path to the root of an i2 Analyze deployment toolkit." 1>&2
  echo "  -t {create}                  Creates a configuration in the i2 Analyze deployment toolkit that can be imported into the config development environment." 1>&2
  echo "  -t {prepare}                 Prepares an existing i2 Analyze deployment toolkit configuration to be imported into the config development environment." 1>&2
  echo "  -t {export}                  Export a config development environment configuration to an i2 Analyze deployment toolkit configuration." 1>&2
  echo "  -t {import}                  Import an i2 Analyze deployment toolkit configuration to a config development environment configuration." 1>&2
  echo "  -y                           Answer 'yes' to all prompts." 1>&2
  echo "  -v                           Verbose output." 1>&2
  echo "  -h                           Display the help." 1>&2
  exit 1
}

function parseArguments() {
  while getopts ":t:c:p:vyh" flag; do
    case "${flag}" in
    t)
      TASK="${OPTARG}"
      [[ "${TASK}" == "import" || "${TASK}" == "export" || "${TASK}" == "create" || "${TASK}" == "prepare" ]] || usage
      ;;
    c)
      CONFIG_NAME="${OPTARG}"
      ;;
    p)
      ON_PREM_TOOLKIT_DIR="${OPTARG}"
      ;;
    v)
      VERBOSE="true"
      ;;
    y)
      YES_FLAG="true"
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

function printErrorAndExit() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
  exit 1
}

function checkPropertySetOrUsage() {
  if [[ -z "${1}" ]]; then
    usage
  fi
}

function validateArguments() {
  checkPropertySetOrUsage "${CONFIG_NAME}"
  checkPropertySetOrUsage "${ON_PREM_TOOLKIT_DIR}"
  checkPropertySetOrUsage "${TASK}"
}

function sourceCommonVariablesAndScripts() {
  # Load common functions
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

  # Load common variables
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/utils/variables.sh"

  setDependenciesTagIfNecessary
}

function checkFileExistsOrError() {
  local file="${1}"
  if [[ ! -f "${file}" ]]; then
    printErrorAndExit "The \"${file}\" file does not exist. Ensure that it is in the configuration directory and has the correct name."
  fi
}

function checkDirectoryExistsOrError() {
  local directory="${1}"
  if [[ ! -d "${directory}" ]]; then
    printErrorAndExit "The \"${directory}\" directory does not exist."
  fi
}

function deleteFileIfExists() {
  local file_path="$1"
  if [[ -f "${file_path}" ]]; then
    rm -f "${file_path}"
  fi
}

function checkIsValidToolkit() {
  for directory in "${REQUIRED_ON_PREM_TOOLKIT_DIRS[@]}"; do
    if [[ ! -d "${ON_PREM_TOOLKIT_DIR}/${directory}" ]]; then
      printErrorAndExit "The specified toolkit is not valid, the \"${directory}\" directory does not exist."
    fi
  done
}

function runTopLevelChecks() {
  checkDirectoryExistsOrError "${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/configuration"
  checkDirectoryExistsOrError "${ON_PREM_TOOLKIT_DIR}"
}

function runLowLevelChecks() {
  checkIsValidToolkit
  checkDeploymentPatternIsValid
}

function validateAndListConnectors() {
  local connector_definitions_file="${GENERATED_LOCAL_CONFIG_DIR}/connectors-template.json"
  local topology_file="${ENVIRONMENT_DIR}/topology.xml"
  local config_connectors_ids
  local on_prem_connectors_ids
  local missing_connectors_ids
  local connector_id

  readarray -t config_connectors_ids < <(jq -r '.connectors[].id' <"${connector_definitions_file}")
  readarray -t on_prem_connectors_ids < <(xmlstarlet sel -t -v "/ns1:topology/applications/application/wars/war/connector-ids/connector-id/@value" "${topology_file}")

  # Compute missing connectors in config-dev
  IFS=' ' read -r -a missing_connectors_ids <<<"$(subtractArrayFromArray config_connectors_ids on_prem_connectors_ids)"

  if [[ -n "${missing_connectors_ids[*]}" ]]; then
    print "Connector ids missing in config-dev"
    printf "%s\n" "${missing_connectors_ids[@]}"
  fi

  # Compute missing connectors in on-prem
  IFS=' ' read -r -a missing_connectors_ids <<<"$(subtractArrayFromArray on_prem_connectors_ids config_connectors_ids)"

  if [[ -n "${missing_connectors_ids[*]}" ]]; then
    print "Connector ids missing in toolkit"
    printf "%s\n" "${missing_connectors_ids[@]}"
  fi
}

function validateFixedProperties() {
  local files_to_grep=()
  local error_messages=()
  local fixed_property
  local grep_result
  local properties_file
  local actual_property
  local fixed_property_value
  local expected_property

  files_to_grep=("${COMMON_CLASSES_DIR}/ApolloServerSettingsMandatory.properties")
  # If analyze-settings.properties does not exist also validate properties in DiscoServerSettingsCommon
  if [[ ! -f "${COMMON_CLASSES_DIR}/analyze-settings.properties" ]]; then
    files_to_grep+=("${OPAL_SERVICES_CLASSES_DIR}/DiscoServerSettingsCommon.properties")
  fi

  # Ensure properties are set to the expected fixed values
  for fixed_property in "${!FIXED_PROPERTIES[@]}"; do
    # Do not validate TypeMappingResource property
    if [[ "${fixed_property}" != "TypeMappingResource" ]]; then
      grep_result=$(grep "^${fixed_property}" "${files_to_grep[@]}")
      properties_file="$(echo "${grep_result}" | cut -d':' -f1)"
      actual_property="$(echo "${grep_result}" | cut -d':' -f2)"
      file_name=$(basename "${properties_file}")
      fixed_property_value=${FIXED_PROPERTIES[${fixed_property}]}
      expected_property="${fixed_property}=${fixed_property_value}"

      if [[ "${actual_property}" != "${expected_property}" ]]; then
        error_messages+=("The \"${actual_property}\" setting must be set to \"${fixed_property_value}\" in the ${file_name} file.")
      fi
    fi
  done

  if [[ "${#error_messages[@]}" -gt 0 ]]; then
    printf "\e[31mERROR: %s\n" "${error_messages[@]}" >&2
    printf "\e[0m" >&2
    exit 1
  fi
}

function appendErrorMessageIfFileNotExist() {
  local file="${1}"
  local error_message="The ${file} file does not exist. Ensure that it is in the configuration directory and has the correct name."
  if [[ ! -f "${file}" ]]; then
    error_messages+=("${error_message}")
  fi
}

function validateFixedFiles() {
  local error_messages=()

  # Ensure the configuration contains the default files
  for file in "${REQUIRED_COMMON_FIXED_FILE_NAMES[@]}"; do
    appendErrorMessageIfFileNotExist "$file"
  done
  allowed_files=("${REQUIRED_COMMON_FIXED_FILE_NAMES[@]}")

  # Check presence of analyze-settings.properties and if exists ensure the files exists
  if [[ -f "${COMMON_CLASSES_DIR}/analyze-settings.properties" ]]; then
    for file in "${REQUIRED_FRAGMENTS_FOR_ANALYZE_SETTINGS_FILE_NAMES[@]}"; do
      appendErrorMessageIfFileNotExist "$file"
    done
    allowed_files+=("${REQUIRED_FRAGMENTS_FOR_ANALYZE_SETTINGS_FILE_NAMES[@]}")
  fi

  # Check deployment pattern and ensure relevant files exist
  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    for file in "${REQUIRED_FRAGMENTS_FOR_ISTORE_DEPLOYMENT_FILE_NAMES[@]}"; do
      appendErrorMessageIfFileNotExist "$file"
    done
    allowed_files+=("${REQUIRED_FRAGMENTS_FOR_ISTORE_DEPLOYMENT_FILE_NAMES[@]}")
  else
    for file in "${REQUIRED_FRAGMENTS_FOR_I2C_DEPLOYMENT_FILE_NAMES[@]}"; do
      appendErrorMessageIfFileNotExist "$file"
    done
    allowed_files+=("${REQUIRED_FRAGMENTS_FOR_I2C_DEPLOYMENT_FILE_NAMES[@]}")
  fi

  if [[ "${#error_messages[@]}" -gt 0 ]]; then
    printf "\e[31mERROR: %s\n" "${error_messages[@]}" >&2
    printf "\e[0m" >&2
    exit 1
  fi
}

function warnIfExtraFiles() {
  if [[ "${TASK}" == "import" ]]; then
    # Ensure there is no other properties file that aren't required
    files_to_validate=("$(find "${ON_PREM_CONFIG_DIR}/"* -type f \( -path "*/fragments/common/WEB-INF/classes/*" \
      -o -path "*/fragments/opal-services/WEB-INF/classes/*" \
      -o -path "*/fragments/opal-services-is/WEB-INF/classes/*" \
      -o -path "*/live/*" \))")

    IFS=' ' read -r -a extra_files <<<"$(subtractArrayFromArray allowed_files files_to_validate)"
    IFS=' ' read -r -a extra_files <<<"$(subtractArrayFromArray IGNORED_FIXED_FILE_NAMES extra_files)"

    if [[ "${#extra_files[@]}" -gt 0 ]]; then
      echo "The following files will not be imported into the config development environment configuration:"
      printf "%s\n" "${extra_files[@]}"

      waitForUserReply "Are you sure you want to continue?"
    fi
  fi
}

function validateFixedNames() {
  local files_to_validate
  local extra_files=()
  local allowed_files

  print "Validating configuration: ${ON_PREM_CONFIG_DIR}"
  validateFixedProperties
  validateFixedFiles
  warnIfExtraFiles
}

function createConfig() {
  local example_configuration
  local example_configuration_path
  local toolkit_config_mod_dir

  print "Running the create task"

  if [[ -d "${ON_PREM_CONFIG_DIR}" ]]; then
    waitForUserReply "To create a new configuration, the previous configuration directory must be deleted. Are you sure you want to delete your current i2 Analyze deployment toolkit configuration?"
    print "Deleting existing ${ON_PREM_CONFIG_DIR}"
    deleteFolderIfExistsAndCreate "${ON_PREM_CONFIG_DIR}"
  else
    createFolder "${ON_PREM_CONFIG_DIR}"
  fi

  case "${DEPLOYMENT_PATTERN}" in
  "i2c_istore")
    example_configuration="information-store-daod-opal"
    ;;
  "i2c")
    example_configuration="daod-opal"
    ;;
  "cstore")
    example_configuration="chart-storage"
    ;;
  "i2c_cstore")
    example_configuration="chart-storage-daod"
    ;;
  "istore")
    example_configuration="information-store-opal"
    ;;
  esac

  print "Copying example ${example_configuration} configuration to ${ON_PREM_TOOLKIT_DIR}"
  example_configuration_path="${EXAMPLES_CONFIGS_DIR}/${example_configuration}/configuration"
  cp -pr "${example_configuration_path}/"* "${ON_PREM_CONFIG_DIR}"

  print "Copying config development environment configuration mods to ${COMMON_CLASSES_DIR}"
  toolkit_config_mod_dir="${ANALYZE_CONTAINERS_ROOT_DIR}/templates/toolkit-config-mod"
  cp -p "${toolkit_config_mod_dir}/analyze-connect.properties" \
    "${toolkit_config_mod_dir}/analyze-settings.properties" \
    "${toolkit_config_mod_dir}/ApolloServerSettingsConfigurationSet.properties" \
    "${toolkit_config_mod_dir}/ApolloServerSettingsMandatory.properties" \
    "${COMMON_CLASSES_DIR}"

  print "Success: configuration created"
}

function renameConfigFiles() {
  local actual_property
  local actual_filename
  local expected_filename

  for fixed_property in "${!FIXED_PROPERTIES[@]}"; do
    actual_property=$(grep -h "^${fixed_property}" "${COMMON_CLASSES_DIR}/ApolloServerSettingsMandatory.properties" "${OPAL_SERVICES_CLASSES_DIR}/DiscoServerSettingsCommon.properties" || true)
    actual_filename="$(echo "${actual_property}" | cut -d'=' -f2)"
    expected_filename="${FIXED_PROPERTIES[${fixed_property}]}"

    if [[ -n "${actual_filename}" ]]; then
      if [[ "${actual_filename}" != "${expected_filename}" ]]; then
        if [[ -n "${actual_filename}" ]]; then
          echo "${actual_filename} > ${expected_filename}"
        fi
        find "${FRAGMENTS_DIR}/"* -type f -name "${actual_filename}" -execdir mv {} "${expected_filename}" \;
      fi
    else
      unset_properties+=("${fixed_property}=${expected_filename}")
    fi
  done
}

function addTemplateConfigFiles() {
  local property_key
  local property_value
  local toolkit_config_mod_dir
  local fragments_classes_dir

  for unset_property in "${unset_properties[@]}"; do
    property_key="$(echo "${unset_property}" | cut -d'=' -f1)"
    property_value="$(echo "${unset_property}" | cut -d'=' -f2)"

    if [[ "${property_key}" == "SchemaResource" ]] || [[ "${property_key}" == "ChartingSchemesResource" ]] ||
      [[ "${property_key}" == "DynamicSecuritySchemaResource" ]] || [[ "${property_key}" == "TypeMappingResource" ]]; then
      fragments_classes_dir="${COMMON_CLASSES_DIR}"
    else
      fragments_classes_dir="${OPAL_SERVICES_CLASSES_DIR}"
    fi

    # If the settings file does not exist then copy a template file
    if [[ ! -f "${fragments_classes_dir}/${property_value}" ]]; then
      echo "Copying template ${property_value} to ${fragments_classes_dir}"
      cp -p "${LOCAL_USER_CONFIG_DIR}/${property_value}" "${fragments_classes_dir}"
    fi

  done
}

# TODO: https://i2group.atlassian.net/browse/TAU-823
# This should be temporary, it should be removed or moved to a different location in the prod-toolkit
function removeExampleVisualQueryExampleFile() {
  local property_key
  local property_value

  for unset_property in "${unset_properties[@]}"; do
    property_key="$(echo "${unset_property}" | cut -d'=' -f1)"
    property_value="$(echo "${unset_property}" | cut -d'=' -f2)"

    if [[ "${property_key}" == "VisualQueryConfigurationResource" ]]; then
      deleteFileIfExists "${OPAL_SERVICES_CLASSES_DIR}/visual-query-configuration.xml"
    fi
  done
}

function updateConfigProperties() {
  local grep_result
  local actual_property
  local expected_property
  local properties_file

  files_to_grep=("${COMMON_CLASSES_DIR}/ApolloServerSettingsMandatory.properties")
  # If analyze-settings.properties does not exist also check properties in DiscoServerSettingsCommon
  if [[ ! -f "${COMMON_CLASSES_DIR}/analyze-settings.properties" ]]; then
    files_to_grep+=("${OPAL_SERVICES_CLASSES_DIR}/DiscoServerSettingsCommon.properties")
  fi

  for fixed_property in "${!FIXED_PROPERTIES[@]}"; do
    # Do not update TypeMappingResource property
    if [[ "${fixed_property}" != "TypeMappingResource" ]]; then
      grep_result=$(grep "^${fixed_property}" "${files_to_grep[@]}")
      properties_file="$(echo "${grep_result}" | cut -d':' -f1)"
      actual_property="$(echo "${grep_result}" | cut -d':' -f2)"
      expected_property="${fixed_property}=${FIXED_PROPERTIES[${fixed_property}]}"

      if [[ "${actual_property}" != "${expected_property}" ]]; then
        echo "Updating ${expected_property}"
        sed -i "s/^${actual_property}/${expected_property}/" "${properties_file}"
      fi
    fi
  done
}

function prepareConfigFiles() {
  local unset_properties

  print "Running the prepare task"

  print "Renaming the schema and configuration files"
  renameConfigFiles

  # See comment above function
  removeExampleVisualQueryExampleFile

  print "Adding template files for unset settings"
  addTemplateConfigFiles

  print "Updating the schema and configuration settings"
  updateConfigProperties

  print "Success: configuration updated"
}

function importDsidPropertiesFile() {
  local dsid_properties_directory_path="${LOCAL_USER_CONFIG_DIR}/environment/dsid"
  local dsid_properties_file_path="${dsid_properties_directory_path}/dsid.properties"
  local on_prem_dsid_properties_file_path
  local topology_id

  topology_id="$(getTopologyId)"
  on_prem_dsid_properties_file_path="${ON_PREM_CONFIG_DIR}/environment/dsid/dsid.${topology_id}.properties"

  if [[ -f "${on_prem_dsid_properties_file_path}" ]]; then
    createFolder "${dsid_properties_directory_path}"
    cp -p "${on_prem_dsid_properties_file_path}" "${dsid_properties_file_path}"
  fi
}

function importConfig() {
  print "Running import task"

  validateFixedNames

  print "Updating configuration: ${LOCAL_USER_CONFIG_DIR}"
  # Copy fragments/common, fragments/opal-services and live configuration files
  cp -p "${REQUIRED_COMMON_FIXED_FILE_NAMES[@]}" "${LOCAL_USER_CONFIG_DIR}"

  # Copy default config-dev files
  cp -pr "${LOCAL_CONFIG_DEV_DIR}/configuration/i2-tools" \
    "${LOCAL_CONFIG_DEV_DIR}/configuration/ingestion" \
    "${LOCAL_CONFIG_DEV_DIR}/configuration/connector-references.json" \
    "${LOCAL_CONFIG_DEV_DIR}/configuration/extension-references.json" \
    "${LOCAL_CONFIG_DEV_DIR}/configuration/log4j2.xml" \
    "${LOCAL_USER_CONFIG_DIR}"

  # Copy solr configuration files
  cp -pr "${ON_PREM_CONFIG_DIR}/solr"/*.* "${LOCAL_USER_CONFIG_DIR}/solr"

  # If the deployment toolkit analyze settings file exists then copy
  if [[ -f "${COMMON_CLASSES_DIR}/analyze-settings.properties" ]]; then
    cp -p "${COMMON_CLASSES_DIR}/analyze-settings.properties" "${LOCAL_USER_CONFIG_DIR}"
  fi

  # Check deployment pattern and copy relevant files
  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    cp -p "${REQUIRED_FRAGMENTS_FOR_ISTORE_DEPLOYMENT_FILE_NAMES[@]}" "${LOCAL_USER_CONFIG_DIR}"
  else
    cp -p "${REQUIRED_FRAGMENTS_FOR_I2C_DEPLOYMENT_FILE_NAMES[@]}" "${LOCAL_USER_CONFIG_DIR}"
  fi

  importDsidPropertiesFile

  if [[ -f "${FRAGMENTS_DIR}/common/privacyagreement.html" ]]; then
    cp -p "${FRAGMENTS_DIR}/common/privacyagreement.html" "${LOCAL_USER_CONFIG_DIR}/privacyagreement.html"
  fi

  print "Success: configuration updated"

  generateArtifacts

  validateAndListConnectors

  print "Generated config is in: ${LOCAL_USER_CONFIG_DIR}"
}

function exportConfig() {
  local apollo_server_settings_file_path
  print "Running export task"

  # Creating transient .configuration and .configuration-generated directories
  generateArtifacts
  createMountedConfigStructure

  print "Generating configuration for the export"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/environment/common"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/i2-tools"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/ingestion"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/solr/generated_config"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/prometheus"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/grafana"
  rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/log4j2.xml"
  rm "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/connectors-template.json"
  rm "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/DiscoSolrConfiguration.properties"
  rm "${LOCAL_CONFIG_DIR}/server.extensions.dev.xml"
  rm "${LOCAL_CONFIG_DIR}/user.registry.xml"

  # If on prem analyze settings file does not exist then exclude files from copy
  # If on prem analyze settings file exists:
  #   Ensure analyze-settings.properties is included
  #   Add required setting to ApolloServerSettingsMandatory

  if [[ ! -f "${COMMON_CLASSES_DIR}/analyze-settings.properties" ]]; then
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/analyze-settings.properties"
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/analyze-connect.properties"
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/ApolloServerSettingsConfigurationSet.properties"
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/ApolloServerSettingsMandatory.properties"
  else
    # Exclude files from copy
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/analyze-connect.properties"
    rm "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/ApolloServerSettingsConfigurationSet.properties"
  fi

  # Check deployment pattern and exclude certain files from copy
  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    createFolder "${LOCAL_CONFIG_DIR}/environment"
    mv "${LOCAL_CONFIG_DIR}/live/system-match-rules.xml" "${LOCAL_CONFIG_DIR}/environment"
  fi

  print "Updating configuration: ${ON_PREM_CONFIG_DIR}"
  cp -r "${LOCAL_CONFIG_DIR}/." "${ON_PREM_CONFIG_DIR}"
  validateFixedNames
  echo "Success: configuration updated"

  validateAndListConnectors
}

function runTask() {
  if [[ "${TASK}" == "create" ]]; then
    createConfig
  elif [[ "${TASK}" == "prepare" ]]; then
    prepareConfigFiles
  elif [[ "${TASK}" == "import" ]]; then
    importConfig
  elif [[ "${TASK}" == "export" ]]; then
    exportConfig
  fi
}

###############################################################################
# Function Calls                                                              #
###############################################################################

parseArguments "$@"
validateArguments
setDefaults
runTopLevelChecks
sourceCommonVariablesAndScripts
warnRootDirNotInPath
runLowLevelChecks
runTask
