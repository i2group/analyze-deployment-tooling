#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

function usage() {
  echo "usage createConfiguration.sh -e {pre-prod|config-dev} [-v]" 1>&2
  exit 1
}

while getopts ":e:v" flag; do
  case "${flag}" in
  e)
    ENVIRONMENT="${OPTARG}"
    ;;
  v)
    VERBOSE="true"
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
checkEnvironmentIsValid
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "aws" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/aws/utils/simulated-external-variables.sh"
fi
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"

###############################################################################
# Variables                                                                   #
###############################################################################
ALL_PATTERNS_CONFIG_DIR="${LOCAL_TOOLKIT_DIR}/examples/configurations/all-patterns/configuration"

###############################################################################
# Function definitions                                                        #
###############################################################################

function createCleanBaseConfiguration() {
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    createCleanBaseConfigurationForPreProd
  elif [[ "${ENVIRONMENT}" == "aws" ]]; then
    createCleanBaseConfigurationForAWS
  elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
    createCleanBaseConfigurationConfigDev
  fi
}

function createCleanBaseConfigurationForPreProd() {
  local local_config_opal_services_classes_dir="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services/WEB-INF/classes"
  local toolkit_examples_dir="${LOCAL_TOOLKIT_DIR}/examples"
  local toolkit_example_grafana_dir="${toolkit_examples_dir}/grafana"
  local toolkit_example_security_config_dir="${toolkit_examples_dir}/security"
  local toolkit_example_schemas_dir="${toolkit_examples_dir}/schemas/en_US"
  local local_config_common_classes_dir="${LOCAL_CONFIGURATION_DIR}/fragments/common/WEB-INF/classes"
  local toolkit_required_config_dir="${LOCAL_TOOLKIT_DIR}/application/required/configuration"

  print "Clearing down configuration"
  deleteFolderIfExists "${LOCAL_CONFIGURATION_DIR}"

  print "Copying all-patterns Configuration to ${LOCAL_CONFIGURATION_DIR}"
  mkdir -p "${LOCAL_CONFIGURATION_DIR}"
  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/"* "${LOCAL_CONFIGURATION_DIR}"

  print "Copying required configuration files"
  cp -pr "${toolkit_required_config_dir}/"* "${LOCAL_CONFIGURATION_DIR}"

  print "Configuring form based authentication"
  xmlstarlet edit -L --subnode "//server" --type elem -n webAppSecurity \
    --insert "// webAppSecurity" --type attr --name "overrideHttpAuthMethod" --value "FORM" \
    --insert "// webAppSecurity" --type attr --name "allowAuthenticationFailOverToAuthMethod" --value "FORM" \
    --insert "// webAppSecurity" --type attr --name "loginFormURL" --value "opal/login.html" \
    --insert "// webAppSecurity" --type attr --name "loginErrorURL" --value "opal/login.html?failed" \
    "${local_config_common_classes_dir}/server.extensions.xml"

  print "Configuring metrics authentication"
  xmlstarlet edit -L --subnode "//server" --type elem -n mpMetrics \
    --insert "// mpMetrics" --type attr --name "authentication" --value "true" \
    "${local_config_common_classes_dir}/server.extensions.xml"

  print "Configuring command access control and security schema"
  cp -pr "${toolkit_example_security_config_dir}/command-access-control.xml" "${local_config_opal_services_classes_dir}"
  cp -pr "${toolkit_example_security_config_dir}/security-schema.xml" "${local_config_common_classes_dir}"

  print "Copying connectors.json"
  cp -pr "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/templates/connectors.json" "${local_config_opal_services_classes_dir}"

  print "Setting schema and charting schema"
  cp -pr "${toolkit_example_schemas_dir}/law-enforcement-schema.xml" "${local_config_common_classes_dir}/schema.xml"
  cp -pr "${toolkit_example_schemas_dir}/law-enforcement-schema-charting-schemes.xml" "${local_config_common_classes_dir}/schema-charting-schemes.xml"

  print "Copying user.registry.xml"
  cp -pr "${toolkit_example_security_config_dir}/user.registry.xml" "${LOCAL_CONFIGURATION_DIR}"

  print "Configuring grafana"
  mkdir -p "${LOCAL_GRAFANA_CONFIG_DIR}"
  cp -pr "${toolkit_examples_dir}/grafana/." "${LOCAL_GRAFANA_CONFIG_DIR}"
  cp -p "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/prometheus-datasource.yml" "${LOCAL_GRAFANA_CONFIG_DIR}/provisioning/datasources/prometheus-datasource.yml"

  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/version" "${LOCAL_CONFIGURATION_DIR}"
  sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" "${LOCAL_CONFIGURATION_DIR}/version"
}

function createCleanBaseConfigurationForAWS() {
  local local_config_opal_services_classes_dir="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services/WEB-INF/classes"
  local toolkit_example_security_config_dir="${LOCAL_TOOLKIT_DIR}/examples/security"
  local toolkit_example_schemas_dir="${LOCAL_TOOLKIT_DIR}/examples/schemas/en_US"
  local local_config_common_classes_dir="${LOCAL_CONFIGURATION_DIR}/fragments/common/WEB-INF/classes"
  local toolkit_required_config_dir="${LOCAL_TOOLKIT_DIR}/application/required/configuration"

  print "Clearing down configuration"
  deleteFolderIfExists "${LOCAL_CONFIGURATION_DIR}"

  print "Copying all-patterns Configuration to ${LOCAL_CONFIGURATION_DIR}"
  mkdir -p "${LOCAL_CONFIGURATION_DIR}"
  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/"* "${LOCAL_CONFIGURATION_DIR}"

  print "Copying required configuration files"
  cp -pr "${toolkit_required_config_dir}/"* "${LOCAL_CONFIGURATION_DIR}"

  print "Configuring form based authentication"
  xmlstarlet edit -L --subnode "//server" --type elem -n webAppSecurity \
    --insert "// webAppSecurity" --type attr --name "overrideHttpAuthMethod" --value "FORM" \
    --insert "// webAppSecurity" --type attr --name "allowAuthenticationFailOverToAuthMethod" --value "FORM" \
    --insert "// webAppSecurity" --type attr --name "loginFormURL" --value "opal/login.html" \
    --insert "// webAppSecurity" --type attr --name "loginErrorURL" --value "opal/login.html?failed" \
    "${local_config_common_classes_dir}/server.extensions.xml"

  print "Configuring command access control and security schema"
  cp -pr "${toolkit_example_security_config_dir}/command-access-control.xml" "${local_config_opal_services_classes_dir}"
  cp -pr "${toolkit_example_security_config_dir}/security-schema.xml" "${local_config_common_classes_dir}"

  print "Copying connectors.json"
  cp -pr "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/templates/connectors.json" "${local_config_opal_services_classes_dir}"

  print "Setting schema and charting schema"
  cp -pr "${toolkit_example_schemas_dir}/law-enforcement-schema.xml" "${local_config_common_classes_dir}/schema.xml"
  cp -pr "${toolkit_example_schemas_dir}/law-enforcement-schema-charting-schemes.xml" "${local_config_common_classes_dir}/schema-charting-schemes.xml"

  print "Copying user.registry.xml"
  cp -pr "${toolkit_example_security_config_dir}/user.registry.xml" "${LOCAL_CONFIGURATION_DIR}"

  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/version" "${LOCAL_CONFIGURATION_DIR}"
  sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" "${LOCAL_CONFIGURATION_DIR}/version"
}

function createCleanBaseConfigurationConfigDev() {
  local toolkit_common_classes_dir="${ALL_PATTERNS_CONFIG_DIR}/fragments/common/WEB-INF/classes"
  local toolkit_opal_services_classes_dir="${ALL_PATTERNS_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes"
  local toolkit_required_config_dir="${LOCAL_TOOLKIT_DIR}/application/required/configuration"
  local toolkit_examples_dir="${LOCAL_TOOLKIT_DIR}/examples"
  local license_prompt_file="${ALL_PATTERNS_CONFIG_DIR}/fragments/common/privacyagreement.html"

  print "Clearing down configuration"
  deleteFolderIfExists "${LOCAL_CONFIGURATION_DIR}"

  print "Copying all-patterns Configuration to ${LOCAL_CONFIGURATION_DIR}"
  mkdir -p "${LOCAL_CONFIGURATION_DIR}"

  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/i2-tools" "${LOCAL_CONFIGURATION_DIR}"

  cp -p "${toolkit_common_classes_dir}/analyze-settings.properties" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${toolkit_common_classes_dir}/server.extensions.xml" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${toolkit_common_classes_dir}/log4j2.xml" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${license_prompt_file}" "${LOCAL_CONFIGURATION_DIR}"

  cp -p "${toolkit_opal_services_classes_dir}/schema-results-configuration.xml" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${toolkit_opal_services_classes_dir}/schema-source-reference-schema.xml" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${toolkit_opal_services_classes_dir}/schema-vq-configuration.xml" "${LOCAL_CONFIGURATION_DIR}"
  cp -p "${toolkit_opal_services_classes_dir}/DiscoSolrConfiguration.properties" "${LOCAL_CONFIGURATION_DIR}"

  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${LOCAL_CONFIGURATION_DIR}"

  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/live/." "${LOCAL_CONFIGURATION_DIR}"

  cp -pr "${toolkit_required_config_dir}/"* "${LOCAL_CONFIGURATION_DIR}"

  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/connector-references.json" "${LOCAL_CONFIGURATION_DIR}"
  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/extension-references.json" "${LOCAL_CONFIGURATION_DIR}"
  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/mapping-configuration.json" "${LOCAL_CONFIGURATION_DIR}"
  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/pom.xml" "${EXTENSIONS_DIR}/pom.xml"
  if [[ ! -f "${EXTENSIONS_DIR}/extension-dependencies.json" ]]; then
    echo "[]" >"${EXTENSIONS_DIR}/extension-dependencies.json"
  fi

  print "Configuring prometheus and grafana"
  mkdir -p "${LOCAL_CONFIGURATION_DIR}/prometheus"
  cp -p "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/prometheus.yml" "${LOCAL_CONFIGURATION_DIR}/prometheus"
  mkdir -p "${LOCAL_CONFIGURATION_DIR}/grafana/dashboards"
  cp -pr "${toolkit_examples_dir}/grafana/dashboards/." "${LOCAL_CONFIGURATION_DIR}/grafana/dashboards"

  if [[ ! -f "$CONNECTOR_IMAGES_DIR"/connector-url-mappings-file.json ]]; then
    echo "[]" >"$CONNECTOR_IMAGES_DIR"/connector-url-mappings-file.json
  fi

  echo "<!-- Replace this with your schema.xml configuration file -->" >"${LOCAL_CONFIGURATION_DIR}/schema.xml"
  echo "<!-- Replace this with your security-schema.xml configuration file -->" >"${LOCAL_CONFIGURATION_DIR}/security-schema.xml"
  echo "<!-- Replace this with your schema-charting-schemes.xml configuration file -->" >"${LOCAL_CONFIGURATION_DIR}/schema-charting-schemes.xml"
  echo "<!-- Replace this with your command-access-control.xml configuration file -->" >"${LOCAL_CONFIGURATION_DIR}/command-access-control.xml"

  cp "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/templates/version" "${LOCAL_CONFIG_DEV_DIR}"
  sed -i "s/^SUPPORTED_I2ANALYZE_VERSION=.*/SUPPORTED_I2ANALYZE_VERSION=${SUPPORTED_I2ANALYZE_VERSION}/g" "${LOCAL_CONFIG_DEV_DIR}/version"
}

function createSolrConfiguration() {
  local LOCAL_SOLR_CONFIG_DIR="${LOCAL_CONFIGURATION_DIR}/solr"

  print "Creating solr configuration"
  cp -pr "${LOCAL_TOOLKIT_DIR}/application/required/configuration/solr/." "${LOCAL_SOLR_CONFIG_DIR}"
}

function copyJdbcDriversToConfiguration() {
  if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
    copyJdbcDriversToConfigurationForPreProd
  fi
}

function copyJdbcDriversToConfigurationForPreProd() {
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers" "${LOCAL_CONFIGURATION_DIR}/environment/common"
}

function createIngestionScriptsFolder() {
  if [[ "${ENVIRONMENT}" == "config-dev" ]]; then
    createFolder "${LOCAL_CONFIGURATION_DIR}/ingestion/scripts"
  fi
}

function createTemplateConfigurationMods() {
  if [[ "${ENVIRONMENT}" == "config-dev" ]]; then
    local toolkit_config_mod_dir="${ANALYZE_CONTAINERS_ROOT_DIR}/templates/toolkit-config-mod"
    local toolkit_common_classes_dir="${ALL_PATTERNS_CONFIG_DIR}/fragments/common/WEB-INF/classes"
    local apollo_server_settings_file_path

    cp -p "${toolkit_common_classes_dir}/analyze-settings.properties" \
      "${toolkit_common_classes_dir}/ApolloServerSettingsConfigurationSet.properties" \
      "${toolkit_common_classes_dir}/ApolloServerSettingsMandatory.properties" \
      "${toolkit_config_mod_dir}"

    echo "# ------------------------ Gateway schemas and charting schemes -----------------------" >"${toolkit_config_mod_dir}/analyze-connect.properties"
  fi
}

###############################################################################
# Re-creating local i2Analyze configuration                                   #
###############################################################################
createCleanBaseConfiguration

###############################################################################
# Creating Solr configuration                                                 #
###############################################################################
createSolrConfiguration

###############################################################################
# Placing jdbc drivers into configuration                                     #
###############################################################################
copyJdbcDriversToConfiguration

###############################################################################
# Creating Ingestion Scripts Folder                                           #
###############################################################################
createIngestionScriptsFolder

###############################################################################
# Creating Template Configuration Mods                                        #
###############################################################################
createTemplateConfigurationMods

print "Configuration has been successfully created"
