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

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

function printUsage() {
  echo "Usage:"
  echo "  deploy.sh -c <config_name> [-t {clean}] [-v] [-y]"
  echo "  deploy.sh -c <config_name> [-t {connectors} [-i <connector1_name>] [-e <connector1_name>]] [-v] [-y]"
  echo "  deploy.sh -c <config_name> [-t {extensions} [-i <extension1_name>] [-e <extension1_name>]] [-v] [-y]"
  echo "  deploy.sh -c <config_name> [-t {backup|restore} [-b <backup_name>]] [-v] [-y]"
  echo "  deploy.sh -c <config_name> -a [-t {connectors} [-i <connector1_name>] [-e <connector1_name>]] -d <deployment_name> -l <dependency_label>] [-v] [-y]"
  echo "  deploy.sh -c <config_name> -a -t {package} -d <deployment_name> -l <dependency_label> [-v]"
  echo "  deploy.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -c <config_name>                       Name of the config to use." 1>&2
  echo "  -t {clean}                             Clean the deployment. Will permanently remove all containers and data." 1>&2
  echo "  -t {extensions}                        Deploy or update the extensions." 1>&2
  echo "  -t {connectors}                        Deploy or update the connectors" 1>&2
  echo "  -t {backup}                            Backup the database." 1>&2
  echo "  -t {restore}                           Restore the database." 1>&2
  echo "  -t {package}                           Prepare production artefacts." 1>&2
  echo "  -i <connector_name>|<extension_name>   Name of the connectors or extensions to deploy and update. To specify multiple values, add additional -i options." 1>&2
  echo "  -e <connector_name>|<extension_name>   Name of the connectors or extensions to not deploy and update. To specify multiple values, add additional -e options." 1>&2
  echo "  -b <backup_name>                       Name of the backup to create or restore. If not specified, the default backup is used." 1>&2
  echo "  -a                                     Produce or use artefacts on AWS." 1>&2
  echo "  -d <deployment_name>                   Name of deployment to use on AWS." 1>&2
  echo "  -l <dependency_label>                  Name of dependency image label to use on AWS." 1>&2
  echo "  -v                                     Verbose output." 1>&2
  echo "  -y                                     Answer 'yes' to all prompts." 1>&2
  echo "  -h                                     Display the help." 1>&2
  exit 1
}

AWS_DEPLOY="false"

while getopts ":c:t:i:e:b:d:l:vayh" flag; do
  case "${flag}" in
  c)
    CONFIG_NAME="${OPTARG}"
    ;;
  t)
    TASK="${OPTARG}"
    [[ "${TASK}" == "clean" || "${TASK}" == "backup" || "${TASK}" == "restore" || "${TASK}" == "connectors" || "${TASK}" == "package" || "${TASK}" == "extensions" ]] || usage
    ;;
  i)
    INCLUDED_CONNECTORS+=("$OPTARG")
    INCLUDED_EXTENSIONS+=("$OPTARG")
    ;;
  e)
    EXCLUDED_CONNECTORS+=("${OPTARG}")
    EXCLUDED_EXTENSIONS+=("${OPTARG}")
    ;;
  b)
    BACKUP_NAME="${OPTARG}"
    ;;
  d)
    DEPLOYMENT_NAME="${OPTARG}"
    ;;
  l)
    I2A_DEPENDENCIES_IMAGES_TAG="${OPTARG}"
    ;;
  v)
    VERBOSE="true"
    ;;
  y)
    YES_FLAG="true"
    ;;
  a)
    AWS_ARTEFACTS="true"
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

if [[ -z "$CONFIG_NAME" ]]; then
  usage
fi

if [[ "${AWS_ARTEFACTS}" && ( -z "${DEPLOYMENT_NAME}" || -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ) ]]; then
  usage
fi

if [[ -z "${AWS_ARTEFACTS}" ]]; then
  AWS_ARTEFACTS="false"
fi

if [[ "${AWS_ARTEFACTS}" == "true" && "${TASK}" == "package" ]]; then
  EXTENSIONS_DEV="false"
else
  EXTENSIONS_DEV="true"
fi

if [[ -z "${YES_FLAG}" ]]; then
  YES_FLAG="false"
fi

if [[ -z "$DEPLOYMENT_NAME" ]]; then
  # Only needed when aws is in use
  DEPLOYMENT_NAME=DEPLOYMENT_NAME_NOT_SET
fi

if [[ -z "$CONFIG_NAME" ]]; then
  I2A_LIBERTY_CONFIGURED_IMAGE_TAG="latest"
else
  I2A_LIBERTY_CONFIGURED_IMAGE_TAG="${CONFIG_NAME}"
fi

if [[ -z "${I2A_DEPENDENCIES_IMAGES_TAG}" ]]; then
  I2A_DEPENDENCIES_IMAGES_TAG="latest"
fi

if [[ "${INCLUDED_CONNECTORS[*]}" && "${EXCLUDED_CONNECTORS[*]}" ]]; then
  printf "\e[31mERROR: Incompatible options: Both (-i) and (-e) were specified.\n" >&2
  printf "\e[0m" >&2
  usage
  exit 1
fi

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ROOT_DIR}/configs/${CONFIG_NAME}/utils/variables.sh"
source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

###############################################################################
# Create Helper Functions                                                     #
###############################################################################

#######################################
# Bash Array pretending to be a dict (using Parameter Substitution)
# Note we cannot use Bash Associative Arrays as Mac OSX is stuck on Bash 3.x
# Variable 'configFinalActionCode' defines the action to take, values are:
# 0 = default, no files changed
# 1 = live, web ui reload
# 2 = requires warm restart
# 3 = database schema change, requires warm/cold restart
# Arguments:
#   None
#######################################
function compareCurrentConfiguration() {
  declare -A checkFilesArray
  checkFilesArray=( [fmr-match-rules.xml]=1
        [system-match-rules.xml]=1
        [geospatial-configuration.json]=1
        [highlight-queries-configuration.xml]=1
        [type-access-configuration.xml]=1
        [user.registry.xml]=1
        [server.extensions.xml]=1
        [server.extensions.dev.xml]=1
        [mapping-configuration.json]=2
        [analyze-settings.properties]=2
        [analyze-connect.properties]=2
        [connectors-template.json]=2
        [extension-references.json]=2
        [log4j2.xml]=2
        [schema-charting-schemes.xml]=2
        [schema-results-configuration.xml]=2
        [schema-source-reference-schema.xml]=2
        [schema-vq-configuration.xml]=2
        [command-access-control.xml]=2
        [DiscoSolrConfiguration.properties]=2
        [schema.xml]=3
        [security-schema.xml]=3
        [environment/dsid/dsid.properties]=3)
  #Add gateway schemas
  for gateway_short_name in "${!GATEWAY_SHORT_NAME_SET[@]}"; do
    checkFilesArray+=([${gateway_short_name}-schema.xml]=1)
    checkFilesArray+=([${gateway_short_name}-schema-charting-schemes.xml]=1)
  done

  # array used to store file changes (if any)
  configFinalActionCode=0
  filesChangedArray=()
  printInfo "Checking configuration for '${CONFIG_NAME}' ..."

  if [ ! -d "${CURRENT_CONFIGURATION_PATH}" ]; then
    printErrorAndExit "Current configuration path '${CURRENT_CONFIGURATION_PATH}' is not valid (no configuration folder present)"
  fi
  if [ ! -d "${PREVIOUS_CONFIGURATION_PATH}" ]; then
    printErrorAndExit "Previous configuration path '${PREVIOUS_CONFIGURATION_PATH}' is not valid (no configuration folder present)"
  fi

  for filename in "${!checkFilesArray[@]}"; do
    # get action code
    configActionCode="${checkFilesArray[${filename}]}"

    # check if filename exists in previous, if so then calc checksum
    if [ -f "${PREVIOUS_CONFIGURATION_PATH}/${filename}" ]; then
      checksumPrevious=$(shasum -a 256 "${PREVIOUS_CONFIGURATION_PATH}/${filename}" | cut -d ' ' -f 1 )
    else
      continue
    fi
    # check if filename exists in current, if so then calc checksum
    if [ -f "${CURRENT_CONFIGURATION_PATH}/${filename}" ]; then
      checksumCurrent=$(shasum -a 256 "${CURRENT_CONFIGURATION_PATH}/${filename}" | cut -d ' ' -f 1 )
    else
      continue
    fi
    # if checksums different then store filename changed and action
    if [[ "$checksumPrevious" != "$checksumCurrent" ]]; then
      printInfo "Previous checksum '${checksumPrevious}' and current checksum '${checksumCurrent}' do not match for filename '${filename}'"
      filesChangedArray+=( "${filename}" )
      # set action if higher severity code
      if [[ "${configActionCode}" -gt "${configFinalActionCode}" ]]; then
        configFinalActionCode="${configActionCode}"
      fi
    fi
  done

  # count number of files changed (elements) in the array
  if [ "${#filesChangedArray[@]}" -eq 0 ]; then
    printInfo "No checksum differences found, configuration files are in sync"
  else
    printInfo "File changes detected, action code is '${configFinalActionCode}'"
  fi
  printInfo "Results in array '${filesChangedArray[*]}'"
}

function compareCurrentExtensions() {
  local extension_references_file="${LOCAL_USER_CONFIG_DIR}/extension-references.json"
  local extension_files
  # Any change to extensions require the same action code 2
  local configActionCode=2

  printInfo "Checking extensions for '${CONFIG_NAME}' ..."
  #Add extensions
  readarray -t extension_files < <( jq -r '.extensions[] | .name + "-" + .version' < "${extension_references_file}")
  for filename in "${extension_files[@]}"; do
    # check if filename exists in previous, if so then calc checksum
    if [ -f "${PREVIOUS_CONFIGURATION_LIB_PATH}/${filename}.jar" ]; then
      checksumPrevious=$(shasum -a 256 "${PREVIOUS_CONFIGURATION_LIB_PATH}/${filename}.jar" | cut -d ' ' -f 1 )
    else
      continue
    fi
    # check if filename exists in current, if so then calc checksum
    if [ -f "${LOCAL_LIB_DIR}/${filename}.jar" ]; then
      checksumCurrent=$(shasum -a 256 "${LOCAL_LIB_DIR}/${filename}.jar" | cut -d ' ' -f 1 )
    else
      continue
    fi
    # if checksums different then store filename changed and action
    if [[ "$checksumPrevious" != "$checksumCurrent" ]]; then
      printInfo "Previous checksum '${checksumPrevious}' and current checksum '${checksumCurrent}' do not match for filename '${filename}.jar'"
      filesChangedArray+=( "lib/${filename}.jar" )
      # set action if higher severity code
      if [[ "${configActionCode}" -gt "${configFinalActionCode}" ]]; then
        configFinalActionCode="${configActionCode}"
      fi
    fi
  done

  # count number of files changed (elements) in the array
  if [ "${#filesChangedArray[@]}" -eq 0 ]; then
    printInfo "No checksum differences found, extension jars are in sync"
  else
    printInfo "Jar changes detected, action code is '${configFinalActionCode}'"
  fi
  printInfo "Results in array '${filesChangedArray[*]}'"
}

function deployZKCluster() {
  print "Running ZooKeeper container"
  runZK "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" "${ZK1_DATA_VOLUME_NAME}" "${ZK1_DATALOG_VOLUME_NAME}" "${ZK1_LOG_VOLUME_NAME}" "1" "zk1"
}

function deploySolrCluster() {
  print "Running Solr container"
  runSolr "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" "${SOLR1_VOLUME_NAME}" "${HOST_PORT_SOLR}" "solr1"
}

function configureZKForSolrCluster() {
  print "Configuring ZooKeeper cluster for Solr"
  runSolrClientCommand solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
  if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
    runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
  fi
  runSolrClientCommand bash -c "echo \"\${SECURITY_JSON}\" > /tmp/security.json && solr zk cp /tmp/security.json zk:/security.json -z ${ZK_HOST}"
}

function configureSolrCollections() {
  print "Configuring Solr collections"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}/solr/generated_config"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateSolrSchemas.sh"
  deleteFolderIfExists "${LOCAL_USER_CONFIG_DIR}/solr/generated_config"
  cp -Rp "${LOCAL_CONFIG_DIR}/solr/generated_config" "${LOCAL_USER_CONFIG_DIR}/solr/generated_config"
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /opt/configuration/solr/generated_config/daod_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n main_index -d /opt/configuration/solr/generated_config/main_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n chart_index -d /opt/configuration/solr/generated_config/chart_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n highlight_index -d /opt/configuration/solr/generated_config/highlight_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index1 -d /opt/configuration/solr/generated_config/match_index
  runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n match_index2 -d /opt/configuration/solr/generated_config/match_index
}

function deleteSolrCollections() {
  print "Deleting Solr collections"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=main_index\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=match_index1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=match_index2\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=chart_index\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=daod_index\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=DELETE&name=highlight_index\""

  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/match_index1/collectionprops.json"
  runSolrClientCommand "/opt/solr-8.8.2/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clear "/collections/chart_index/collectionprops.json"
}

function createSolrCollections() {
  print "Creating Solr collections"
  # The curl command uses the container's local environment variables to obtain the SOLR_ADMIN_DIGEST_USERNAME and SOLR_ADMIN_DIGEST_PASSWORD.
  # To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
  # Any double quotes in the curl command are also escaped by a leading backslash.
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=main_index&collection.configName=main_index&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index1&collection.configName=match_index1&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=match_index2&collection.configName=match_index2&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=chart_index&collection.configName=chart_index&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=daod_index&collection.configName=daod_index&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
  runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_CERTS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=highlight_index&collection.configName=highlight_index&numShards=1&maxShardsPerNode=4&replicationFactor=1\""
}

function createDatabase() {
  printInfo "Removing existing database container"
  case "${DB_DIALECT}" in
  db2)
    deleteContainer "${DB2_SERVER_CONTAINER_NAME}"
    docker volume rm -f "${DB2_SERVER_VOLUME_NAME}" "${DB_BACKUP_VOLUME_NAME}"
    createFolder "${DB_BACKUP_VOLUME_NAME}"
    initializeDb2Server
    ;;
  sqlserver)
    deleteContainer "${SQL_SERVER_CONTAINER_NAME}"
    docker volume rm -f "${SQL_SERVER_VOLUME_NAME}" "${DB_BACKUP_VOLUME_NAME}"
    createFolder "${DB_BACKUP_VOLUME_NAME}"
    initializeSQLServer
    ;;
  esac
}

function restoreDatabase() {
  case "${DB_DIALECT}" in
  db2)
    printErrorAndExit "Not implemented yet"
    ;;
  sqlserver)
    restoreSQlServer
    ;;
  esac
}

function restoreSQlServer() {
  deploySecureSQLServer
  restoreIstoreDatabase
  recreateSQLServerUsers
}

function restoreIstoreDatabase() {
  if [[ -z "${BACKUP_NAME}" ]]; then
    print "No backup_name provided, using the 'default' name"
    BACKUP_NAME="default"
  fi
  print "Restoring the ISTORE database"
  sql_query="\
    RESTORE DATABASE ISTORE FROM DISK = '${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}/${DB_BACKUP_FILE_NAME}';"
  runSQLServerCommandAsSA runSQLQuery "${sql_query}"
}

function recreateSQLServerUsers() {
  print "Dropping ISTORE users"
  sql_query="\
    USE ISTORE;
      DROP USER dba;
        DROP USER i2analyze;
          DROP USER i2etl;
            DROP USER etl;
              DROP USER dbb;"
  runSQLServerCommandAsSA runSQLQuery "${sql_query}"

  print "Creating database logins and users"
  createDbLoginAndUser "dbb" "db_backupoperator"
  createDbLoginAndUser "dba" "DBA_Role"
  createDbLoginAndUser "i2analyze" "i2Analyze_Role"
  createDbLoginAndUser "i2etl" "i2_ETL_Role"
  createDbLoginAndUser "etl" "External_ETL_Role"
  runSQLServerCommandAsSA "/opt/db-scripts/configureDbaRolesAndPermissions.sh"
  runSQLServerCommandAsSA "/opt/db-scripts/addEtlUserToSysAdminRole.sh"
}

function initializeDb2Server() {
  deploySecureDb2Server
  initializeIStoreDatabase
  configureIStoreDatabase
  docker exec "${DB2_SERVER_CONTAINER_NAME}" bash -c "su -p db2inst1 -c \". ${DB_LOCATION_DIR}/sqllib/db2profile && db2 UPDATE DB CFG FOR ${DB_NAME} USING extbl_location '${DB_LOCATION_DIR};/var/i2a-data'\""
}

function deploySecureDb2Server() {
  runDb2Server
  waitForDb2ServerToBeLive "true"
  changeDb2inst1Password
}

function initializeSQLServer() {
  deploySecureSQLServer
  initializeIStoreDatabase
  configureIStoreDatabase
}

function deploySecureSQLServer() {
  runSQLServer
  waitForSQLServerToBeLive "true"
  changeSAPassword
}

function initializeIStoreDatabaseForDb2Server() {
  runDb2ServerCommandAsDb2inst1 "/opt/databaseScripts/generated/runDatabaseCreationScripts.sh"

  print "Initializing ISTORE database tables"
  runDb2ServerCommandAsDb2inst1 "/opt/databaseScripts/generated/runStaticScripts.sh"
}

function initializeIStoreDatabaseForSQLServer() {
  runSQLServerCommandAsSA "/opt/databaseScripts/generated/runDatabaseCreationScripts.sh"

  printInfo "Creating database roles"
  runSQLServerCommandAsSA "/opt/db-scripts/createDbRoles.sh"

  printInfo "Creating database logins and users"
  createDbLoginAndUser "dbb" "db_backupoperator"
  createDbLoginAndUser "dba" "DBA_Role"
  createDbLoginAndUser "i2analyze" "i2Analyze_Role"
  createDbLoginAndUser "i2etl" "i2_ETL_Role"
  createDbLoginAndUser "etl" "External_ETL_Role"
  runSQLServerCommandAsSA "/opt/db-scripts/configureDbaRolesAndPermissions.sh"
  runSQLServerCommandAsSA "/opt/db-scripts/addEtlUserToSysAdminRole.sh"

  print "Initializing ISTORE database tables"
  runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runStaticScripts.sh"
}

function initializeIStoreDatabase() {
  print "Initializing ISTORE database"
  printInfo "Generating ISTORE scripts"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateInfoStoreToolScripts.sh"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateStaticInfoStoreCreationScripts.sh"
  
  printInfo "Running ISTORE static scripts"
  case "${DB_DIALECT}" in
    db2)
      initializeIStoreDatabaseForDb2Server
      ;;
    sqlserver)
      initializeIStoreDatabaseForSQLServer
      ;;
  esac
}

function configureIStoreDatabase() {
  print "Configuring ISTORE database"
  runi2AnalyzeTool "/opt/i2-tools/scripts/generateDynamicInfoStoreCreationScripts.sh"
  case "${DB_DIALECT}" in
    db2)
      runDb2ServerCommandAsDb2inst1 "/opt/databaseScripts/generated/runDynamicScripts.sh"
      ;;
    sqlserver)
      runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runDynamicScripts.sh"
      ;;
  esac
}

function deployLiberty() {
  print "Building Liberty Configured image"
  buildLibertyConfiguredImage
  print "Running Liberty container"
  runLiberty "${LIBERTY1_CONTAINER_NAME}" "${I2_ANALYZE_FQDN}" "${LIBERTY1_VOLUME_NAME}" "${HOST_PORT_I2ANALYZE_SERVICE}" "${I2_ANALYZE_CERT_FOLDER_NAME}" "${LIBERTY1_DEBUG_PORT}"
}

function restartConnectorsForConfig() {
  local connector_references_file="${LOCAL_USER_CONFIG_DIR}/connector-references.json"
  # local connector_fqdn
  # local configuration_path

  readarray -t all_connector_ids < <( jq -r '.connectors[].name' < "${connector_references_file}")

  for gateway_short_name in "${all_connector_ids[@]}"; do
    container_id=$(docker ps -a -q -f name="${CONNECTOR_PREFIX}${gateway_short_name}" -f status=exited)
    if [[ -n ${container_id} ]]; then
      print "Restarting connector container"
      docker start "${CONNECTOR_PREFIX}${gateway_short_name}"
    fi
  done
}

function createDeployment() {
  # Validate Configuration
  validateMandatoryFilesPresent
  
  if [[ "${STATE}" == "0" ]]; then
    # Cleaning up Docker resources
    removeAllContainersForTheConfig "${CONFIG_NAME}"
    removeDockerVolumes

     # Running Solr and ZooKeeper
     deployZKCluster
     configureZKForSolrCluster
     deploySolrCluster

     # Configuring Solr and ZooKeeper
     waitForSolrToBeLive "${SOLR1_FQDN}"
     configureSolrCollections
     createSolrCollections
     updateStateFile "1"
  fi

  if [[ "${STATE}" == "0" || "${STATE}" == "1" ]]; then
    # Configuring ISTORE
    if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
      if [[ "${TASK}" == "create" ]]; then
        createDatabase
      elif [[ "${TASK}" == "restore" ]]; then
        restoreDatabase
      else
        printErrorAndExit "Unknown task: ${TASK}"
      fi
    fi
    updateStateFile "2"
  fi

  # Restart connectors
  restartConnectorsForConfig

  # Configuring i2 Analyze
  if [[ "${STATE}" != "0" ]]; then
    print "Removing Liberty container"
    deleteContainer "${LIBERTY1_CONTAINER_NAME}"
  fi
  deployLiberty
  updateLog4jFile
  addConfigAdmin

  # Creating a copy of the configuration that was deployed originally
  printInfo "Initializing diff tool"
  deleteFolderIfExistsAndCreate "${PREVIOUS_CONFIGURATION_PATH}"
  updatePreviousConfigurationWithCurrent
  cp -pr "${LOCAL_LIB_DIR}" "${PREVIOUS_CONFIGURATION_LIB_PATH}"

  # Validate Configuration
  checkLibertyStatus
  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    updateMatchRules
  fi
  updateStateFile "4"
  print "Deployed Successfully"
  echo "This application is configured for access on ${FRONT_END_URI}"
}

###############################################################################
# Update Helper Functions                                                     #
###############################################################################

function notifyUpdateUserRegistry() {
  printInfo "Updating user.registry.xml on i2 Analyze Application"
  if curl \
    -s -o "/tmp/response.txt" \
    --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
    --write-out "%{http_code}" \
    --cookie /tmp/cookie.txt \
    --header 'Content-Type: application/json' \
    --data-raw "{\"params\":[{\"value\" : [\"\"],\"type\" : {\"className\":\"java.util.ArrayList\",\"items\":[\"java.lang.String\"]}},{\"value\" : [\"/opt/ibm/wlp/usr/shared/config/user.registry.xml\"],\"type\" : {\"className\":\"java.util.ArrayList\",\"items\":[\"java.lang.String\"]}},{\"value\" : [\"\"],\"type\" : {\"className\":\"java.util.ArrayList\",\"items\":[\"java.lang.String\"]}}],\"signature\":[\"java.util.Collection\",\"java.util.Collection\",\"java.util.Collection\"]}" \
    --request POST "${BASE_URI}/IBMJMXConnectorREST/mbeans/WebSphere%3Aservice%3Dcom.ibm.ws.kernel.filemonitor.FileNotificationMBean/operations/notifyFileChanges" \
    > /tmp/http_code.txt; then
    # Invoking FileNotificationMBean doc: https://www.ibm.com/docs/en/zosconnect/3.0?topic=demand-invoking-filenotificationmbean-from-rest-api
    http_status_code=$(cat /tmp/http_code.txt)
    if [[ "${http_status_code}" != 200 ]]; then
      printErrorAndExit "Problem updating user.registry.xml application. Returned:${http_status_code}"
    else
      printInfo "Response from i2 Analyze Web UI:$(cat /tmp/response.txt)"
    fi
  else
    printErrorAndExit "Problem calling curl:$(cat /tmp/http_code.txt)"
  fi
}

function updateLiveConfiguration() {
  local errors_message="Validation errors detected, please review the above message(s)."

  for fileName in "${filesChangedArray[@]}"; do
    if [[ "${fileName}" == "user.registry.xml" ]]; then
      notifyUpdateUserRegistry
      break
    fi
  done 

  print "Calling reload endpoint"
  if curl \
    -s -o /tmp/response.txt -w "%{http_code}" \
    --cookie /tmp/cookie.txt \
    --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
    --header "Origin: ${FRONT_END_URI}" \
    --header 'Content-Type: application/json' \
    --request POST "${FRONT_END_URI}/api/v1/admin/config/reload" > /tmp/http_code.txt; then
    http_code=$(cat /tmp/http_code.txt)
    if [[ "${http_code}" != "200" ]]; then
      jq '.errorMessage' /tmp/response.txt
      printErrorAndExit "${errors_message}"
    else
      echo "No Validation errors detected."
    fi
  else
    printErrorAndExit "Problem calling reload endpoint"
  fi
}

function callGatewayReload() {
  local errors_message="Validation errors detected, please review the above message(s)."
  
  loginToLiberty
  print "Calling gateway reload endpoint"
  if curl \
    -s -o /tmp/response.txt -w "%{http_code}" \
    --cookie /tmp/cookie.txt \
    --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
    --header "Origin: ${FRONT_END_URI}" \
    --header 'Content-Type: application/json' \
    --request POST "${FRONT_END_URI}/api/v1/gateway/reload" > /tmp/http_code.txt; then
    http_code=$(cat /tmp/http_code.txt)
    if [[ "${http_code}" != "200" ]]; then
      jq '.errorMessage' /tmp/response.txt
      printErrorAndExit "${errors_message}"
    else
      echo "No Validation errors detected."
    fi
  else
    printErrorAndExit "Problem calling reload endpoint"
  fi
}

function loginToLiberty() {
  local MAX_TRIES=10
  local app_admin_password

  app_admin_password=$(getApplicationAdminPassword)

  printInfo "Getting Auth cookie"
  for i in $(seq 1 "${MAX_TRIES}"); do
    if curl \
      -s -o /tmp/response.txt \
      --write-out "%{http_code}" \
      --cookie-jar /tmp/cookie.txt \
      --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
      --request POST "${BASE_URI}/IBMJMXConnectorREST/j_security_check" \
      --header "Origin: ${BASE_URI}" \
      --header 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "j_username=${I2_ANALYZE_ADMIN}" \
      --data-urlencode "j_password=${app_admin_password}" > /tmp/http_code.txt; then
      http_status_code=$(cat /tmp/http_code.txt)
      if [[ "${http_status_code}" -eq 302 ]]; then
        echo "Logged in to Liberty server" && return 0
      else
        printInfo "Failed login with status code:${http_status_code}"
      fi
    fi
    echo "Liberty is NOT live (attempt: $i). Waiting..."
    sleep 10
  done
  printInfo "Liberty won't start- resetting"
  updateStateFile "2"
  printErrorAndExit "Could not authenticate with Liberty- please try again"
}

function controlApplication() {
  local operation="$1"
  printInfo "Running '${operation}' on i2 Analyze Application"
  if curl \
    -s -o "/tmp/response.txt" \
    --cacert "${LOCAL_EXTERNAL_CA_CERT_DIR}/CA.cer" \
    --write-out "%{http_code}" \
    --cookie /tmp/cookie.txt \
    --header 'Content-Type: application/json' \
    --data-raw '{}' \
    --request POST "${BASE_URI}/IBMJMXConnectorREST/mbeans/WebSphere%3Aname%3Dopal-services%2Cservice%3Dcom.ibm.websphere.application.ApplicationMBean/operations/${operation}" \
    > /tmp/http_code.txt; then
    http_status_code=$(cat /tmp/http_code.txt)
    if [[ "${http_status_code}" != 200 ]]; then
      printErrorAndExit "Problem restarting application. Returned:${http_status_code}"
    else
      printInfo "Response from i2 Analyze Web UI:$(cat /tmp/response.txt)"
    fi
  else
    printErrorAndExit "Problem calling curl:$(cat /tmp/http_code.txt)"
  fi
}

function restartApplication() {
   controlApplication restart
}

function stopApplication() {
   controlApplication stop
}

function startApplication() {
   controlApplication start
}

function copyLocalConfigToTheLibertyContainer() {
  local liberty_server_path="liberty/wlp/usr/servers/defaultServer"
  printInfo "Copying configuration to the Liberty container (${LIBERTY1_CONTAINER_NAME})"

  # All other configuration is copied to the application WEB-INF/classes directory.
  local tmp_classes_dir="${ROOT_DIR}/tmp_classes"
  createFolder "${tmp_classes_dir}"
  find "${GENERATED_LOCAL_CONFIG_DIR}" -maxdepth 1 -type f ! -name user.registry.xml ! -name extension-references.json ! -name connector-references.json ! -name '*.xsd' ! -name server.extensions.xml ! -name server.extensions.dev.xml -exec cp -t "${tmp_classes_dir}" {} \;

  # In the schema_dev deployment point Gateway schemes to the ISTORE schemes
  if [[ "${DEPLOYMENT_PATTERN}" == "schema_dev" ]]; then
    sed -i 's/^SchemaResource=/Gateway.External.SchemaResource=/' "${tmp_classes_dir}/ApolloServerSettingsMandatory.properties"
    sed -i 's/^ChartingSchemesResource=/Gateway.External.ChartingSchemesResource=/' "${tmp_classes_dir}/ApolloServerSettingsMandatory.properties"
  fi

  docker cp "${tmp_classes_dir}/." "${LIBERTY1_CONTAINER_NAME}:${liberty_server_path}/apps/opal-services.war/WEB-INF/classes"
  if [[ -f "${GENERATED_LOCAL_CONFIG_DIR}/server.extensions.xml" ]]; then
    docker cp "${GENERATED_LOCAL_CONFIG_DIR}/server.extensions.xml" "${LIBERTY1_CONTAINER_NAME}:${liberty_server_path}"
  fi
  if [[ -f "${GENERATED_LOCAL_CONFIG_DIR}/server.extensions.dev.xml" ]]; then
    docker cp "${GENERATED_LOCAL_CONFIG_DIR}/server.extensions.dev.xml" "${LIBERTY1_CONTAINER_NAME}:${liberty_server_path}"
  fi
  rm -rf "${tmp_classes_dir}"

  updateLog4jFile
  addConfigAdmin

  connector_url_map_new=$(cat "${CONNECTOR_IMAGES_DIR}"/connector-url-mappings-file.json)

  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c "export CONNECTOR_URL_MAP='${connector_url_map_new}'; \
    rm /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/classes/connectors.json; \
    rm /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/allready_run; \
    /opt/create-connector-config.sh"
}

function updatePreviousConfigurationWithCurrent() {
  printInfo "Copying configuration from (${CURRENT_CONFIGURATION_PATH}) to (${PREVIOUS_CONFIGURATION_PATH})"
  cp -pR "${CURRENT_CONFIGURATION_PATH}"/* "${PREVIOUS_CONFIGURATION_PATH}"
  createFolder "${PREVIOUS_CONFIGURATION_UTILS_PATH}"
  cp -p "${CURRENT_CONFIGURATION_UTILS_PATH}/variables.sh" "${PREVIOUS_CONFIGURATION_UTILS_PATH}/variables.sh"
}

function updateMatchRules() {
  print "Updating system match rules"

  printInfo "Uploading system match rules"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" update_match_rules

  printInfo "Waiting for the standby match index to complete indexing"
  local stand_by_match_index_ready_file_path="/logs/StandbyMatchIndexReady"
  while docker exec "${LIBERTY1_CONTAINER_NAME}" test ! -f "${stand_by_match_index_ready_file_path}"; do
    printInfo "waiting..."
    sleep 3
  done

  print "Switching standby match index to live"
  runi2AnalyzeTool "/opt/i2-tools/scripts/runIndexCommand.sh" switch_standby_match_index_to_live

  printInfo "Removing StandbyMatchIndexReady file from the liberty container"
  docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c "rm ${stand_by_match_index_ready_file_path} > /dev/null 2>&1"
}

function rebuildDatabase() {
  waitForUserReply "Do you wish to rebuild the ISTORE database? This will permanently remove data from the deployment."
  case "${DB_DIALECT}" in
    db2)
      printInfo "Removing existing Db2 Server container"
      deleteContainer "${DB2_SERVER_CONTAINER_NAME}"
      docker volume rm -f "${DB2_SERVER_VOLUME_NAME}" "${DB_BACKUP_VOLUME_NAME}"
      initializeDb2Server
      ;;
    sqlserver)
      printInfo "Removing existing SQL Server container"
      deleteContainer "${SQL_SERVER_CONTAINER_NAME}"
      docker volume rm -f "${SQL_SERVER_VOLUME_NAME}" "${DB_BACKUP_VOLUME_NAME}"
      initializeSQLServer
      ;;
  esac
}

function updateSchema() {
  local errors_message="Validation errors detected, please review the above message(s)"

  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    print "Updating the deployed schema"

    printInfo "Stopping Liberty container"
    stopApplication

    printInfo "Validating the schema"
    if ! runi2AnalyzeTool "/opt/i2-tools/scripts/validateSchemaAndSecuritySchema.sh" > '/tmp/result_validate_security_schema'; then
      startApplication
      echo "[INFO] Response from i2 Analyze Tool: $(cat '/tmp/result_validate_security_schema')"
      # check i2 Analyze Tool for output indicating a Schema change has occured, if so then prompt user for destructive
      # rebuild of ISTORE database.
      #
      # Note the error message from i2 Analyze is currently not great and incorrectly indicates that the 'Schema file
      # is not valid', what it really means is its not valid for the current deployment and thus must be re-deployed via
      # a destructive change to the ISTORE database.
      if grep -q 'ERROR: The new Schema file is not valid, see the summary for more details.' '/tmp/result_validate_security_schema'; then
        echo "[WARN] Destructive Schema change(s) detected"
        destructiveSchemaOrSecuritySchemaChange
        echo "[INFO] Destructive Schema change(s) complete"
      else
        printErrorAndExit "${errors_message}"
      fi
    else
      deleteFolderIfExists "${LOCAL_GENERATED_DIR}/update"

      printInfo "Generating update schema scripts"
      runi2AnalyzeTool "/opt/i2-tools/scripts/generateUpdateSchemaScripts.sh"
      if [ -d "${LOCAL_GENERATED_DIR}/update" ]; then
        if [ "$(ls -A "${LOCAL_GENERATED_DIR}/update")" ]; then
          printInfo "Running the generated scripts"
          case "${DB_DIALECT}" in
            db2)
              runDb2ServerCommandAsDb2inst1 "/opt/databaseScripts/generated/runDatabaseScripts.sh" "/opt/databaseScripts/generated/update"
              ;;
            sqlserver)
              runSQLServerCommandAsDBA "/opt/databaseScripts/generated/runDatabaseScripts.sh" "/opt/databaseScripts/generated/update"
              ;;
          esac
        else
          printInfo "No files present in update schema scripts folder"
        fi
      else
        printInfo "Update schema scripts folder doesn't exist"
      fi
    fi
  fi
}

function updateSecuritySchema() {
  local result_update_security_schema
  local result_update_security_schema_exitcode
  local errors_message="Validation errors detected, please review the above message(s)"

  if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    print "Updating the deployed security schema"

    printInfo "Stopping Liberty application"
    stopApplication

    printInfo "Updating security schema"
    if ! runi2AnalyzeTool "/opt/i2-tools/scripts/updateSecuritySchema.sh" > '/tmp/result_update_security_schema'; then
      startApplication
      echo "[INFO] Response from i2 Analyze Tool: $(cat '/tmp/result_update_security_schema')"
      # check i2 Analyze Tool for output indicating a Security Schema change has occured, if so then prompt user for destructive
      # rebuild of ISTORE database.
      if grep -q 'ILLEGAL STATE: The new security schema has incompatible differences with the existing one' '/tmp/result_update_security_schema'; then
        echo "[WARN] Destructive Security Schema change(s) detected"
        destructiveSchemaOrSecuritySchemaChange
        echo "[INFO] Destructive Security Schema change(s) complete"
      else
        printErrorAndExit "${errors_message}"
      fi
    fi
  fi
}

function destructiveSchemaOrSecuritySchemaChange() {
  rebuildDatabase
  deleteSolrCollections
  createSolrCollections
}

function updateDataSourceIdFile() {
  local tmp_dir="/tmp"
  createDataSourceProperties "${tmp_dir}"

  docker cp "${tmp_dir}/DataSource.properties" "${LIBERTY1_CONTAINER_NAME}:liberty/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/classes"
}

function handleConfigurationChange() {
  compareCurrentConfiguration
  compareCurrentExtensions

  if [[ "${configFinalActionCode}" == "0" ]]; then
    print "No updates to the configuration"
    updatePreviousConfigurationWithCurrent
    waitForLibertyToBeLive
    updateStateFile "4"
    return
  fi

  # Make sure update will be re-run if anything fails
  updateStateFile "3"
  for fileName in "${filesChangedArray[@]}"; do
    if [[ "${fileName}" == "system-match-rules.xml" ]]; then
      updateMatchRules
    elif [[ "${fileName}" == "schema.xml" ]]; then
      updateSchema
    elif [[ "${fileName}" == "security-schema.xml" ]]; then
      updateSecuritySchema
    elif [[ "${fileName}" == "user.registry.xml" ]]; then
      addConfigAdminToUserRegistry
    elif [[ "${fileName}" == "environment/dsid/dsid.properties" ]]; then
      updateDataSourceIdFile
      if [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
        destructiveSchemaOrSecuritySchemaChange
      fi
    elif [[ "${fileName}" == "extension-references.json" || "${fileName}" = lib/*.jar ]]; then
      handleExtensionChange
    fi
  done

  if [[ "${configFinalActionCode}" == "3" ]] && [[ "${DEPLOYMENT_PATTERN}" == *"store"* ]]; then
    printInfo "Starting i2 Analyze application"
    startApplication

    printInfo "Validating database consistency"
    runi2AnalyzeTool "/opt/i2-tools/scripts/dbConsistencyCheckScript.sh"
  fi

  copyLocalConfigToTheLibertyContainer
  if [[ "${configFinalActionCode}" != "1" ]]; then
    printInfo "Restarting i2 Analyze application"
    clearLibertyValidationLog
    restartApplication
    checkLibertyStatus
  else
    printInfo "Calling reload endpoint"
    waitForLibertyToBeLive
    updateLiveConfiguration
  fi
  updatePreviousConfigurationWithCurrent
  updateStateFile "4"
}

function handleDeploymentPatternChange() {
  printInfo "Checking if DEPLOYMENT_PATTERN changed"

  if [[ "${CURRENT_DEPLOYMENT_PATTERN}" != "${PREVIOUS_DEPLOYMENT_PATTERN}" ]]; then
    print "DEPLOYMENT_PATTERN is changed"
    echo "Previous DEPLOYMENT_PATTERN: ${PREVIOUS_DEPLOYMENT_PATTERN}"
    echo "New DEPLOYMENT_PATTERN: ${CURRENT_DEPLOYMENT_PATTERN}"

    print "Removing Liberty container"
    deleteContainer "${LIBERTY1_CONTAINER_NAME}"
    deployLiberty
    updateLog4jFile
    addConfigAdmin
    loginToLiberty

    if [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" == *"store"* ]] && [[ "${CURRENT_DEPLOYMENT_PATTERN}" != *"store"* ]]; then
      print "Stopping SQL Server container"
      docker stop "${SQL_SERVER_CONTAINER_NAME}"
    fi

    if [[ "${CURRENT_DEPLOYMENT_PATTERN}" == *"store"* ]] && [[ "${PREVIOUS_DEPLOYMENT_PATTERN}" != *"store"* ]]; then
      sql_server_container_status="$(docker ps -a --format "{{.Status}}" -f network="${DOMAIN_NAME}" -f name="${SQL_SERVER_CONTAINER_NAME}")"
      if [[ "${sql_server_container_status%% *}" == "Up" ]]; then
        print "SQl Server container is already running"
        updateSchema
      elif [[ "${sql_server_container_status%% *}" == "Exited" ]]; then
        print "Starting SQL Server container"
        docker start "${SQL_SERVER_CONTAINER_NAME}"
        waitForSQLServerToBeLive
        updateSchema
      else
        print "Removing SQL Server volumes"
        docker volume rm -f "${SQL_SERVER_VOLUME_NAME}" "${DB_BACKUP_VOLUME_NAME}"

        updateStateFile "1"
        initializeSQLServer

        updateStateFile "2"
      fi
    fi
    stopApplication
    clearLibertyValidationLog
    startApplication
    checkLibertyStatus
    updateStateFile "4"
  else
    printInfo "DEPLOYMENT_PATTERN is unchanged: ${CURRENT_DEPLOYMENT_PATTERN}"
  fi
}

function handleExtensionChange() {
  local jars_liberty_path="liberty/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/lib"
  local extension_references_file="${LOCAL_USER_CONFIG_DIR}/extension-references.json"
  local extension_files
  local filename 

  print "Updating i2Analyze extensions"

  # Remove jars that aren't there anymore
  if [[ -d "${PREVIOUS_CONFIGURATION_LIB_PATH}" ]]; then
    for path in "${PREVIOUS_CONFIGURATION_LIB_PATH}"/*; do
      if [[ ! -e "${path}" ]]; then 
        continue
      fi
      filename=$(basename "${path}")
      if [ ! -f "${LOCAL_LIB_DIR}/${filename}" ]; then
        printInfo "Delete old library ${jars_liberty_path}/${filename}"
        docker exec "${LIBERTY1_CONTAINER_NAME}" bash -c "rm ${jars_liberty_path}/${filename} > /dev/null 2>&1"
      fi
    done
  fi
  
  deleteFolderIfExistsAndCreate "${PREVIOUS_CONFIGURATION_LIB_PATH}"
  readarray -t extension_files < <( jq -r '.extensions[] | .name + "-" + .version' < "${extension_references_file}")

  for filename in "${extension_files[@]}"; do
    cp -pr "${LOCAL_LIB_DIR}/${filename}.jar" "${PREVIOUS_CONFIGURATION_LIB_PATH}"
  done

  # Update all Extension jars
  printInfo "Copy current Extension jars to Liberty container"
  docker cp "${PREVIOUS_CONFIGURATION_LIB_PATH}/." "${LIBERTY1_CONTAINER_NAME}:${jars_liberty_path}"
}

function updateDeployment() {
  
  # Validate Configuration
  validateMandatoryFilesPresent

  # Restart Docker containers
  restartDockerContainersForConfig "${CONFIG_NAME}"
  restartConnectorsForConfig

  # Login to Liberty
  loginToLiberty

  # Handling DEPLOYMENT_PATTERN Change
  handleDeploymentPatternChange

  # Handling Configuration Change
  handleConfigurationChange

  print "Updated Successfully"
  echo "This application is configured for access on ${FRONT_END_URI}"
}

###############################################################################
# Backup Helper Functions                                                     #
###############################################################################

function moveBackupIfExist() {
  print "Checking backup does NOT exist"
  local backup_file_path="${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}/${DB_BACKUP_FILE_NAME}"
  if [[ -f "${backup_file_path}" ]]; then
    local old_backup_file_path="${backup_file_path}.bak"
    if [[ "${BACKUP_NAME}" != "default" ]]; then
      waitForUserReply "Backup already exist, are you sure you want to overwrite it?"
    fi
    echo "Backup ${backup_file_path} already exists, moving it to ${old_backup_file_path}"
    mv "${backup_file_path}" "${old_backup_file_path}"
  fi
}

function createBackup() {
  if [[ "${DB_DIALECT}" == "db2" ]]; then
    printErrorAndExit "Not implemented yet"
  fi
  # Restart Docker containers
  restartDockerContainersForConfig "${CONFIG_NAME}"
  restartConnectorsForConfig

  # Check for backup file
  if [[ -z "${BACKUP_NAME}" ]]; then
    print "No backup_name provided, using the 'default' name"
    BACKUP_NAME="default"
  fi

  moveBackupIfExist

  createFolder "${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}"

  # Create the back up
  print "Backing up the ISTORE database"
  local backup_file_path="${DB_CONTAINER_BACKUP_DIR}/${BACKUP_NAME}/${DB_BACKUP_FILE_NAME}"
  local sql_query="\
    USE ISTORE;
      BACKUP DATABASE ISTORE
      TO DISK = '${backup_file_path}'
      WITH FORMAT;"
  runSQLServerCommandAsDBB runSQLQuery "${sql_query}"

  # Update backup file permission to your local user
  docker exec "${SQL_SERVER_CONTAINER_NAME}" bash -c "chown $(id -u "$USER"):$(id -g "$USER") ${backup_file_path}"
}

function restoreFromBackup() {
  if [[ -z "${BACKUP_NAME}" ]]; then
    print "No backup_name provided, using the 'default' name"
    BACKUP_NAME="default"
  fi

  # Validate the backup exists and is not zero bytes before continuing.
  if [[ ! -d "${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}" ]]; then
    printErrorAndExit "Backup directory ${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME} does NOT exist"
  fi
  if [[ ! -f "${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}/ISTORE.bak" || ! -s "${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}/ISTORE.bak" ]]; then
    printErrorAndExit "Backup file ${ROOT_DIR}/backups/${CONFIG_NAME}/${BACKUP_NAME}/ISTORE.bak does NOT exist or is empty."
  fi

  waitForUserReply "Are you sure you want to run the 'restore' task? This will permanently remove data from the deployment and restore to the specified backup."
  updateStateFile "0"
  STATE="0"
  createDeployment
}

###############################################################################
# Clean Helper Functions                                                      #
###############################################################################

function cleanDeployment() {
  waitForUserReply "Are you sure you want to run the 'clean' task? This will permanently remove data from the deployment."

  local all_container_names
  IFS=' ' read -ra all_container_names <<< "$(docker ps -a -q -f network="${DOMAIN_NAME}" -f name="${CONFIG_NAME}" | xargs)"
  print "Deleting all containers for ${CONFIG_NAME} deployment"
  for container_name in "${all_container_names[@]}"; do
    deleteContainer "${container_name}"
  done

  removeDockerVolumes

  printInfo "Deleting deployed extensions: ${LOCAL_LIB_DIR}"
  deleteFolderIfExists "${LOCAL_LIB_DIR}"

  printInfo "Deleting previous configuration folder: ${PREVIOUS_CONFIGURATION_DIR}"
  deleteFolderIfExists "${PREVIOUS_CONFIGURATION_DIR}"
}

###############################################################################
# Connector Helper Functions                                                  #
###############################################################################

function updateConnectors() {
  local connector_args
  local included_connector
  local excluded_connector

  if [[ -n "${INCLUDED_CONNECTORS[*]}" ]]; then
    for included_connector in "${INCLUDED_CONNECTORS[@]}"; do
      connector_args+=(-i "${included_connector}")
    done
  elif [[ -n "${EXCLUDED_CONNECTORS[*]}" ]]; then
    for excluded_connector in "${EXCLUDED_CONNECTORS[@]}"; do
      connector_args+=(-e "${excluded_connector}")
    done
  else
    connector_args=()
  fi

  if [[ "${YES_FLAG}" == "true" ]]; then
    connector_args+=(-y)
  fi
  if [[ "${VERBOSE}" == "true" ]]; then
    connector_args+=(-v)
  fi

  if [[ "${AWS_ARTEFACTS}" == "true" ]]; then
    print "Running generateSecrets.sh"
    "${ROOT_DIR}/utils/generateSecrets.sh" -a -l "${I2A_DEPENDENCIES_IMAGES_TAG}" -c connectors "${connector_args[@]}"
    print "Running buildConnectorImages.sh"
    "${ROOT_DIR}/utils/buildConnectorImages.sh" -a -d "${DEPLOYMENT_NAME}" -l "${I2A_DEPENDENCIES_IMAGES_TAG}" "${connector_args[@]}"
  else
    print "Running generateSecrets.sh"
    "${ROOT_DIR}/utils/generateSecrets.sh" -c connectors "${connector_args[@]}"
    print "Running buildConnectorImages.sh"
    "${ROOT_DIR}/utils/buildConnectorImages.sh" "${connector_args[@]}"
  fi
}

###############################################################################
# Deploy Helper Functions                                                     #
###############################################################################

function initializeDeployment() {
  printInfo "Initializing deployment"
  if [[ "${AWS_ARTEFACTS}" = "true" ]]; then
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_BASE_NAME}"
  fi

  # Auto generate dsid into config folder before we create the generated one
  createDataSourceId
  
  generateArtefacts

  # Add files that could be missing
  if [[ ! -f "${LOCAL_USER_CONFIG_DIR}/extension-references.json" ]]; then
    cp "${LOCAL_CONFIGURATION_DIR}/extension-references.json" "${LOCAL_USER_CONFIG_DIR}/extension-references.json"
  fi

  addConfigAdminToSecuritySchema
  createMountedConfigStructure
  mkdir -p "${LOCAL_LIB_DIR}"

  if [[ ! -f "${PREVIOUS_STATE_FILE_PATH}" ]]; then
    createInitialStateFile
  fi
}

function validateMandatoryFilesPresent() {
  local mandatory_files=(
    "schema.xml"
    "schema-charting-schemes.xml"
    "security-schema.xml"
    "schema-results-configuration.xml"
    "command-access-control.xml"
    "schema-source-reference-schema.xml"
    "schema-vq-configuration.xml"
  )

  for mandatory_file in "${mandatory_files[@]}"; do
    if [[ ! -f "${LOCAL_USER_CONFIG_DIR}/${mandatory_file}" ]]; then
      printErrorAndExit "Mandatory file ${mandatory_file} missing from ${LOCAL_USER_CONFIG_DIR}, correct this problem then run deploy.sh again."
    fi
  done;

  for xml_file in "${LOCAL_USER_CONFIG_DIR}"/*.xml; do
    if [[ $(head "${xml_file}") == *"<!-- Replace this"* ]]; then
      file_name=$(basename "$xml_file")
      printErrorAndExit "Placeholder text found in ${LOCAL_USER_CONFIG_DIR}/${file_name}, check file contents then run deploy.sh again."
    fi
  done;
}

function createInitialStateFile() {
  local template_state_file_path="${ROOT_DIR}/utils/templates/.state.sh"
  printInfo "Creating initial ${PREVIOUS_STATE_FILE_PATH} file"
  createFolder "${PREVIOUS_CONFIGURATION_DIR}"
  cp -p "${template_state_file_path}" "${PREVIOUS_STATE_FILE_PATH}"
  STATE=0
}

function updateStateFile() {
  local new_state="$1"
  printInfo "Updating ${PREVIOUS_STATE_FILE_PATH} with state: ${new_state}"
  sed -i "s/STATE=.*/STATE=${new_state}/g" "${PREVIOUS_STATE_FILE_PATH}"
}

function workOutTaskToRun() {
  source "${PREVIOUS_STATE_FILE_PATH}"
  printInfo "STATE: ${STATE}"

  if [[ "${STATE}" == "0" ]]; then
    print "Creating initial deployment"
    TASK="create"
  elif [[ "${STATE}" == "1" ]] || [[ "${STATE}" == "2" ]]; then
    print "Previous deployment did not complete - retrying"
    TASK="create"
  elif [[ "${STATE}" == "3" ]]; then
    print "Current Deployment is NOT healthy"
    TASK="update"
  elif [[ "${STATE}" == "4" ]]; then
    print "Updating deployment"
    TASK="update"
  fi

  if [[ "${TASK}" == "update" ]]; then
    if ! checkContainersExist; then
      print "Some containers are missing, the deployment is NOT healthy."
      waitForUserReply "Do you want to clean and recreate the deployment? This will permanently remove data from the deployment."
      # Reset state
      STATE=0
      TASK="create"
    fi
    if ! checkConnectorContainersExist; then
      # Reset state
      STATE=0
      TASK="create"
      printErrorAndExit "Some connector containers are missing, the deployment is NOT healthy."    
    fi
  fi
}

function runTopLevelChecks() {
  checkEnvironmentIsValid
  checkDeploymentPatternIsValid
  checkClientFunctionsEnvironmentVariablesAreSet
  checkVariableIsSet "${HOST_PORT_SOLR}" "HOST_PORT_SOLR environment variable is not set"
  checkVariableIsSet "${HOST_PORT_I2ANALYZE_SERVICE}" "HOST_PORT_I2ANALYZE_SERVICE environment variable is not set"
  checkVariableIsSet "${HOST_PORT_DB}" "HOST_PORT_DB environment variable is not set"
}

function printDeploymentInformation () {
  print "Deployment Information:"
  echo "CONFIG_NAME: ${CONFIG_NAME}"
  echo "DEPLOYMENT_PATTERN: ${DEPLOYMENT_PATTERN}"
}

function runTask () {
  case "${TASK}" in
  "create")
    createDeployment
    ;;
  "update")
    updateDeployment
    ;;
  "clean")
    cleanDeployment
    ;;
  "backup")
    createBackup
    ;;
  "restore")
    restoreFromBackup
    ;;
  esac
}

function runNormalDeployment() {
  workOutTaskToRun
  runTask
}

###############################################################################
# Function Calls                                                              #
###############################################################################

runTopLevelChecks
printDeploymentInformation

initializeDeployment

# If you would like to call a specific function you should do it after this line

# Cleaning up Docker resources
cleanUpDockerResources
createDockerNetwork "${DOMAIN_NAME}"

if [[ -z "${TASK}" ]]; then
  runNormalDeployment
elif [[ "${TASK}" == "connectors" ]]; then
  #Get connectors uptodate
  updateConnectors
  #Run normal deployment
  runNormalDeployment
  #Reload gateway
  callGatewayReload
elif [[ "${TASK}" == "extensions" ]]; then
  #Get extensions uptodate
  deployExtensions
  #Run normal deployment
  runNormalDeployment
elif [[ "${TASK}" == "package" ]]; then
  buildLibertyConfiguredImage
else
  runTask
fi
