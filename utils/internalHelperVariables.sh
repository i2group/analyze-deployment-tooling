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
# shellcheck disable=SC2034

# This file defines variables that are shared between config-dev & pre-prod environments.
# It containers variables that should NOT be changed by the end-user.
# Examples:
# - Paths
# - Development variable
# NOTE: this file has a dependency on the commonVariables.sh file.

###############################################################################
# Volume names                                                                #
###############################################################################
ZK1_DATA_VOLUME_NAME="${ZK1_CONTAINER_NAME}_data"
ZK1_DATALOG_VOLUME_NAME="${ZK1_CONTAINER_NAME}_datalog"
ZK1_LOG_VOLUME_NAME="${ZK1_CONTAINER_NAME}_logs"
ZK2_DATA_VOLUME_NAME="${ZK2_CONTAINER_NAME}_data"
ZK2_DATALOG_VOLUME_NAME="${ZK2_CONTAINER_NAME}_datalog"
ZK2_LOG_VOLUME_NAME="${ZK2_CONTAINER_NAME}_logs"
ZK3_DATA_VOLUME_NAME="${ZK3_CONTAINER_NAME}_data"
ZK3_DATALOG_VOLUME_NAME="${ZK3_CONTAINER_NAME}_datalog"
ZK3_LOG_VOLUME_NAME="${ZK3_CONTAINER_NAME}_logs"
SOLR1_VOLUME_NAME="${SOLR1_CONTAINER_NAME}_data"
SOLR2_VOLUME_NAME="${SOLR2_CONTAINER_NAME}_data"
SOLR3_VOLUME_NAME="${SOLR3_CONTAINER_NAME}_data"
LIBERTY1_VOLUME_NAME="${LIBERTY1_CONTAINER_NAME}_data"
LIBERTY2_VOLUME_NAME="${LIBERTY2_CONTAINER_NAME}_data"
SQL_SERVER_VOLUME_NAME="${SQL_SERVER_CONTAINER_NAME}_sqlvolume"
DB2_SERVER_VOLUME_NAME="${DB2_SERVER_CONTAINER_NAME}_sqlvolume"
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  # Use named volume in pre-prod
  DB_BACKUP_VOLUME_NAME="${SQL_SERVER_CONTAINER_NAME}_sqlbackup"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  # Use bind mount in config-dev
  DB_BACKUP_VOLUME_NAME="${ROOT_DIR}/backups/${CONFIG_NAME}"
fi
SOLR_BACKUP_VOLUME_NAME="${SOLR1_CONTAINER_NAME}_solr_backup"

###############################################################################
# Security configuration                                                      #
###############################################################################
CA_DURATION="90"
CERTFICIATE_DURATION="90"
CERTIFICATE_KEY_SIZE=4096
CA_KEY_SIZE=4096
I2_ANALYZE_CERT_FOLDER_NAME="i2analyze"
GATEWAY_CERT_FOLDER_NAME="gateway_user"
ADMIN_ACCESS_PERMISSIONS=("i2:Administrator" "i2:Notes" "i2:RecordsUpload" "i2:RecordsDelete" "i2:ChartsUpload" "i2:ChartsDelete" \
  "i2:ChartsRead" "i2:RecordsExport" "i2:Connectors" "i2:Connectors:connector-id" "i2:Notebook")

###############################################################################
# Backup and restore variables                                                #
###############################################################################
SOLR_BACKUP_VOLUME_LOCATION="/backup"
MAIN_INDEX_BACKUP_NAME="main_index_backup"
MATCH_INDEX_BACKUP_NAME="match1_index_backup"
CHART_INDEX_BACKUP_NAME="chart_index_backup"

###############################################################################
# Root Paths                                                                  #
###############################################################################
# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

IMAGES_DIR="${ROOT_DIR}/images"
TEMPLATES_DIR="${ROOT_DIR}/templates"
CONNECTOR_PREFIX="connector-"
CONNECTOR_IMAGES_DIR="${ROOT_DIR}/connector-images"
EXTENSIONS_DIR="${ROOT_DIR}/i2a-extensions"
GATEWAY_SCHEMA_DIR="${ROOT_DIR}/gateway-schemas"
LOCAL_ETL_TOOLKIT_DIR="${IMAGES_DIR}/etl_client/etltoolkit"
LOCAL_EXAMPLE_CONNECTOR_APP_DIR="${IMAGES_DIR}/example_connector/app"

LOCAL_CONFIG_DEV_DIR="${ROOT_DIR}/templates/config-development"
LOCAL_CONFIG_TOOLKIT_MOD_DIR="${ROOT_DIR}/templates/toolkit-config-mod"
PRE_PROD_DIR="${ROOT_DIR}/examples/pre-prod"
AWS_DIR="${ROOT_DIR}/examples/aws"

if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  LOCAL_PRE_PROD_CONFIG_DIR="${PRE_PROD_DIR}/configuration"
  LOCAL_CONFIGURATION_DIR="${LOCAL_PRE_PROD_CONFIG_DIR}"
  LOCAL_ISTORE_NAMES_SQL_SERVER_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services-is/WEB-INF/classes/InfoStoreNamesSQLServer.properties"
  LOCAL_ISTORE_NAMES_DB2_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services-is/WEB-INF/classes/InfoStoreNamesDb2.properties"
  LOCAL_DATABASE_SCRIPTS_DIR="${PRE_PROD_DIR}/database-scripts"
elif [[ "${ENVIRONMENT}" == "aws" ]]; then
  LOCAL_AWS_CONFIG_DIR="${AWS_DIR}/configuration"
  LOCAL_CONFIGURATION_DIR="${LOCAL_AWS_CONFIG_DIR}"
  LOCAL_ISTORE_NAMES_SQL_SERVER_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services-is/WEB-INF/classes/InfoStoreNamesSQLServer.properties"
  LOCAL_ISTORE_NAMES_DB2_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services-is/WEB-INF/classes/InfoStoreNamesDb2.properties"
  LOCAL_DATABASE_SCRIPTS_DIR="${AWS_DIR}/database-scripts"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  LOCAL_CONFIG_DEV_CONFIG_DIR="${LOCAL_CONFIG_DEV_DIR}/configuration"
  LOCAL_CONFIGURATION_DIR="${LOCAL_CONFIG_DEV_CONFIG_DIR}"
  LOCAL_ISTORE_NAMES_SQL_SERVER_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/InfoStoreNamesSQLServer.properties"
  LOCAL_ISTORE_NAMES_DB2_PROPERTIES_FILE="${LOCAL_CONFIGURATION_DIR}/InfoStoreNamesDb2.properties"
  LOCAL_DATABASE_SCRIPTS_DIR="${LOCAL_CONFIG_DEV_DIR}/database-scripts"
  PREVIOUS_CONFIGURATION_DIR="${ROOT_DIR}/configs/${CONFIG_NAME}/.${CONFIG_NAME}"
  PREVIOUS_CONFIGURATION_PATH="${PREVIOUS_CONFIGURATION_DIR}/configuration"
  PREVIOUS_CONFIGURATION_LIB_PATH="${PREVIOUS_CONFIGURATION_DIR}/lib"
  CURRENT_CONFIGURATION_PATH="${GENERATED_LOCAL_CONFIG_DIR}"
  PREVIOUS_CONFIGURATION_UTILS_PATH="${PREVIOUS_CONFIGURATION_DIR}/utils"
  CURRENT_CONFIGURATION_UTILS_PATH="${ROOT_DIR}/configs/${CONFIG_NAME}/utils"
  if [[ -f "${PREVIOUS_CONFIGURATION_UTILS_PATH}/variables.sh" ]]; then
    source "${PREVIOUS_CONFIGURATION_UTILS_PATH}/variables.sh"
  fi
  PREVIOUS_DEPLOYMENT_PATTERN="${DEPLOYMENT_PATTERN}"
  if [[ -f "${CURRENT_CONFIGURATION_UTILS_PATH}/variables.sh" ]]; then
    source "${CURRENT_CONFIGURATION_UTILS_PATH}/variables.sh"
  fi
  CURRENT_DEPLOYMENT_PATTERN="${DEPLOYMENT_PATTERN}"
  PREVIOUS_STATE_FILE_PATH="${PREVIOUS_CONFIGURATION_DIR}/.state.sh"
fi

###############################################################################
# Configuration paths                                                         #
###############################################################################
LOCAL_CONFIG_COMMON_DIR="${LOCAL_CONFIGURATION_DIR}/fragments/common/WEB-INF/classes"
LOCAL_CONFIG_OPAL_SERVICES_DIR="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services/WEB-INF/classes"
LOCAL_CONFIG_OPAL_SERVICES_IS_DIR="${LOCAL_CONFIGURATION_DIR}/fragments/opal-services-is/WEB-INF/classes"
LOCAL_CONFIG_I2_TOOLS_DIR="${LOCAL_CONFIGURATION_DIR}/i2-tools/classes"
LOCAL_CONFIG_LIVE_DIR="${LOCAL_CONFIGURATION_DIR}/live"

###############################################################################
# Security paths                                                              #
###############################################################################
LOCAL_KEYS_DIR="${ROOT_DIR}/dev-environment-secrets/simulated-secret-store"
GENERATED_SECRETS_DIR="${ROOT_DIR}/dev-environment-secrets/generated-secrets"
LOCAL_CA_CERT_DIR="${GENERATED_SECRETS_DIR}/certificates/CA"
LOCAL_EXTERNAL_CA_CERT_DIR="${GENERATED_SECRETS_DIR}/certificates/externalCA"
CONNECTOR_CONFIG_FILE="connector.conf.json"
CONNECTOR_SECRETS_FILE="connector.secrets.json"

###############################################################################
# Walkthrough paths                                                           #
###############################################################################
PRE_PROD_DIR="${ROOT_DIR}/examples/pre-prod"
LOCAL_CONFIG_CHANGES_DIR="${PRE_PROD_DIR}/walkthroughs/change-management/configuration-changes"

###############################################################################
# Localisation variables                                                      #
###############################################################################
SOLR_LOCALE="en_US"

###############################################################################
# Container secrets paths                                                     #
###############################################################################
CONTAINER_SECRETS_DIR="/run/secrets"
CONTAINER_CERTS_DIR="/tmp/i2acerts"

###############################################################################
# Connector variables                                                         #
###############################################################################
I2CONNECT_SERVER_CONNECTOR_TYPE="i2connect-server"
EXTERNAL_CONNECTOR_TYPE="external"

###############################################################################
# AWS variables                                                               #
###############################################################################
CFN_STACKS=("vpc" "security" "storage" "launch-templates" "solr" "sqlserver" "admin-client" "main")

declare -gA CFN_STACKS_PARAMS_MAP
CFN_STACKS_PARAMS_MAP=(
  [main]="DeploymentName ResourcesS3Bucket"
  [vpc]="DeploymentName"
  [security]="DeploymentName VpcId"
  [storage]="DeploymentName PrivateSubnetAId"
  [launch-templates]="DeploymentName ResourcesS3Bucket"
  [solr]="DeploymentName PrivateSubnetAId ResourcesS3Bucket"
  [sqlserver]="DeploymentName PrivateSubnetAId"
  [admin-client]="DeploymentName PrivateSubnetAId ResourcesS3Bucket"
  [liberty]="VpcId PrivateSubnetAId PublicSubnetAId PublicSubnetBId DBDialect SQLServerFQDN DB2ServerFQDN ZKHost ConnectorUrlMap CertificateArn EnvType DeploymentName"
  [connectors]="DeploymentName VpcId"
  [connector]="DeploymentName VpcId PrivateSubnetAId ConnectorName ConnectorTag"
)

declare -gA RUNBOOKS_MAP
RUNBOOKS_MAP=(
  [i2a-SolrFirstRun]="${AWS_DIR}/i2a-runbooks/solr/i2a-solr-first-run.yaml"
  [i2a-SolrStart]="${AWS_DIR}/i2a-runbooks/solr/i2a-solr-start.yaml"
  [i2a-SqlServerFirstRun]="${AWS_DIR}/i2a-runbooks/sqlserver/i2a-sqlserver-first-run.yaml"
  [i2a-UpdateScripts]="${AWS_DIR}/i2a-runbooks/helpers/i2a-update-scripts.yaml"
)

PRIVATE_SUBNET_A_ID_EXPORT_NAME="${DEPLOYMENT_NAME}-PrivateSubnetAId"
PUBLIC_SUBNET_A_ID_EXPORT_NAME="${DEPLOYMENT_NAME}-PublicSubnetAId"
PUBLIC_SUBNET_B_ID_EXPORT_NAME="${DEPLOYMENT_NAME}-PublicSubnetBId"
VPC_ID_EXPORT_NAME="${DEPLOYMENT_NAME}-VpcId"

SSM_PARAM_NAME_PREFIX="/${DEPLOYMENT_NAME}"
DB_DIALECT_SSM_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/DB_DIALECT"
SQL_SERVER_FQDN_SSM_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/SQL_SERVER_FQDN"
DB2_SERVER_FQDN_SSM_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/DB2_SERVER_FQDN"
ZK_MEMBERS_SSM_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/ZK_MEMBERS"
CONNECTOR_URL_MAP_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/CONNECTOR_URL_MAP"
I2A_CERTIFICATE_ARN_PARAM_NAME="${SSM_PARAM_NAME_PREFIX}/I2A_CERTIFICATE_ARN"

#TODO: Review in Liberty story if we still want this to be a param
AWS_ENV_TYPE="test"

###############################################################################
# Development variables                                                       #
###############################################################################
USE_LOAD_BALANCER_FOR_ACCESS="true"

if [ "${USE_LOAD_BALANCER_FOR_ACCESS}" == "true" ]; then
  LOCAL_CA_CERT_DIR_FOR_CURL="${LOCAL_EXTERNAL_CA_CERT_DIR}"
else
  LOCAL_CA_CERT_DIR_FOR_CURL="${LOCAL_CA_CERT_DIR}"
fi

DEBUG_LIBERTY_SERVERS=()
# Provide a list of liberty container names to start in debug mode such as:
# DEBUG_LIBERTY_SERVERS=("${LIBERTY1_CONTAINER_NAME}" "${LIBERTY2_CONTAINER_NAME}")

# Windows (WSL)
DEVELOPMENT_JARS_DIR="/c/IBM/iap-discovery/Liberty/wlp/usr/servers/is-daod/apps/opal-services-is-daod.war/WEB-INF/lib"
# Mac OS
# DEVELOPMENT_JARS_DIR="/users/[NAME]/deploy/wlp/usr/servers/is-daod/apps/opal-services-is-daod.war/WEB-INF/lib"


