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

###############################################################################
# Start of function definitions                                               #
###############################################################################

#######################################
# Run a Zookeeper server container.
# Arguments:
#   1. ZK container name
#   2. ZK container FQDN
#   3  ZK data volume name
#   4. ZK datalog volume name
#   5. ZK log volume name
#   6. ZK port (on the host machine)
#   7. Zoo ID (an identifier for the ZooKeeper server)
#######################################
function runZK() {
  local CONTAINER="$1"
  local FQDN="$2"
  local DATA_VOLUME="$3"
  local DATALOG_VOLUME="$4"
  local LOG_VOLUME="$5"
  local ZOO_ID="$6"
  local SECRET_LOCATION="$7"
  print "ZooKeeper container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -v "${DATA_VOLUME}:/data" \
    -v "${DATALOG_VOLUME}:/datalog" \
    -v "${LOG_VOLUME}:/logs" \
    -v "${LOCAL_KEYS_DIR}/${SECRET_LOCATION}:${CONTAINER_SECRETS_DIR}" \
    -e "ZOO_SERVERS=${ZOO_SERVERS}" \
    -e "ZOO_MY_ID=${ZOO_ID}" \
    -e "ZOO_SECURE_CLIENT_PORT=${ZK_SECURE_CLIENT_PORT}" \
    -e "ZOO_CLIENT_PORT=2181" \
    -e "ZOO_4LW_COMMANDS_WHITELIST=ruok, mntr, conf" \
    -e "ZOO_MAX_CLIENT_CNXNS=100" \
    -e "SERVER_SSL=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}"/server.key \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/server.cer \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/CA.cer \
    "${ZOOKEEPER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a Solr server container.
# Arguments:
#   1. Solr container name
#   2. Solr container FQDN
#   3. Solr volume name
#   4. Solr port (on the host machine)
#######################################
function runSolr() {
  local CONTAINER="$1"
  local FQDN="$2"
  local VOLUME="$3"
  local HOST_PORT="$4"
  local SECRET_LOCATION="$5"
  print "Solr container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    --init \
    -p "${HOST_PORT}":8983 \
    -v "${VOLUME}:/var/solr" \
    -v "${SOLR_BACKUP_VOLUME_NAME}:${SOLR_BACKUP_VOLUME_LOCATION}" \
    -v "${LOCAL_KEYS_DIR}/${SECRET_LOCATION}:${CONTAINER_SECRETS_DIR}" \
    -e SOLR_OPTS="-Dsolr.allowPaths=${SOLR_BACKUP_VOLUME_LOCATION}" \
    -e "ZK_HOST=${ZK_HOST}" \
    -e "SOLR_HOST=${FQDN}" \
    -e "ZOO_DIGEST_USERNAME=${ZK_DIGEST_USERNAME}" \
    -e "ZOO_DIGEST_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/ZK_DIGEST_PASSWORD" \
    -e "ZOO_DIGEST_READONLY_USERNAME=${ZK_DIGEST_READONLY_USERNAME}" \
    -e "ZOO_DIGEST_READONLY_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/ZK_DIGEST_READONLY_PASSWORD" \
    -e "SOLR_ZOO_SSL_CONNECTION=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SERVER_SSL=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}"/server.key \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/server.cer \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/CA.cer \
    "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a SQL Server container.
# Arguments:
#   None
#######################################
function runSQLServer() {
  print "SQL Server container ${SQL_SERVER_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${SQL_SERVER_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${SQL_SERVER_FQDN}" \
    -p "${HOST_PORT_DB}:1433" \
    -v "${SQL_SERVER_VOLUME_NAME}:/var/opt/mssql" \
    -v "${SQL_SERVER_BACKUP_VOLUME_NAME}:${DB_CONTAINER_BACKUP_DIR}" \
    -v "${LOCAL_KEYS_DIR}/sqlserver:${CONTAINER_SECRETS_DIR}" \
    -v "${DATA_DIR}:/var/i2a-data" \
    -e "ACCEPT_EULA=${ACCEPT_EULA}" \
    -e "MSSQL_AGENT_ENABLED=true" \
    -e "MSSQL_PID=${MSSQL_PID}" \
    -e "SA_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/SA_PASSWORD" \
    -e "SERVER_SSL=${DB_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}"/server.key \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/server.cer \
    "${SQL_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a Liberty Server container.
# Arguments:
#   1. Liberty container name
#   2. Liberty container FQDN
#   3. Liberty volume name
#   4. Liberty port (on the host machine)
#   5. Liberty key folder
#   6. (Optional) Liberty debug port (will be exposed as the same port)
#######################################
function runLiberty() {
  local CONTAINER="$1"
  local FQDN="$2"
  local VOLUME="$3"
  local HOST_PORT="$4"
  local KEY_FOLDER="$5"
  local DEBUG_PORT="$6"

  local libertyStartCommand=()
  local runInDebug

  if [[ ${DEBUG_LIBERTY_SERVERS[*]} =~ (^|[[:space:]])"${CONTAINER}"($|[[:space:]]) ]]; then
      runInDebug=true
  else
      runInDebug=false
  fi

  if [[ "${runInDebug}" == false ]]; then
      print "Liberty container ${CONTAINER} is starting"
    libertyStartCommand+=("${LIBERTY_CONFIGURED_IMAGE_NAME}:${I2A_LIBERTY_CONFIGURED_IMAGE_TAG}")
  else
    print "Liberty container ${CONTAINER} is starting in debug mode"
    if [ -z "$6" ]; then
      echo "No Debug port provided to runLiberty. Debug port must be set if running a container in debug mode!"
      exit 1
    fi

    libertyStartCommand+=("-p")
    libertyStartCommand+=("${DEBUG_PORT}:${DEBUG_PORT}")
    libertyStartCommand+=("-e")
    libertyStartCommand+=("WLP_DEBUG_ADDRESS=0.0.0.0:${DEBUG_PORT}")
    libertyStartCommand+=("-e")
    libertyStartCommand+=("WLP_DEBUG_SUSPEND=y")
    libertyStartCommand+=("${LIBERTY_CONFIGURED_IMAGE_NAME}:${I2A_LIBERTY_CONFIGURED_IMAGE_TAG}")
    libertyStartCommand+=("/opt/ibm/wlp/bin/server")
    libertyStartCommand+=("debug")
    libertyStartCommand+=("defaultServer")
  fi

  #Pass in mappings environment if there is one
  if [[ "${ENVIRONMENT}" == "config-dev" && -f ${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json ]]; then
    CONNECTOR_URL_MAP=$(cat "${CONNECTOR_IMAGES_DIR}"/connector-url-mappings-file.json)
  fi
  
  docker run -m 2g -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${HOST_PORT}:9443" \
    -v "${LOCAL_KEYS_DIR}/${KEY_FOLDER}:${CONTAINER_SECRETS_DIR}" \
    -v "${VOLUME}:/data" \
    -e "LICENSE=${LIC_AGREEMENT}" \
    -e "DB_DIALECT=${DB_DIALECT}" \
    -e "DB_SERVER=${SQL_SERVER_FQDN}" \
    -e "DB_PORT=${DB_PORT}" \
    -e "DB_USERNAME=${I2_ANALYZE_USERNAME}" \
    -e "DB_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/DB_PASSWORD" \
    -e "ZK_HOST=${ZK_MEMBERS}" \
    -e "ZOO_DIGEST_USERNAME=${ZK_DIGEST_USERNAME}" \
    -e "ZOO_DIGEST_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/ZK_DIGEST_PASSWORD" \
    -e "SOLR_HTTP_BASIC_AUTH_USER=${SOLR_APPLICATION_DIGEST_USERNAME}" \
    -e "SOLR_HTTP_BASIC_AUTH_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/SOLR_APPLICATION_DIGEST_PASSWORD" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SOLR_ZOO_SSL_CONNECTION=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SERVER_SSL=${LIBERTY_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/server.key" \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/server.cer" \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/CA.cer" \
    -e "GATEWAY_SSL_CONNECTION=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_OUTBOUND_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/gateway_user.key" \
    -e "SSL_OUTBOUND_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/gateway_user.cer" \
    -e "SSL_OUTBOUND_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/outbound_CA.cer" \
    -e "LIBERTY_HADR_MODE=1" \
    -e "LIBERTY_HADR_POLL_INTERVAL=1" \
    -e "CONNECTOR_URL_MAP=${CONNECTOR_URL_MAP}" \
    "${libertyStartCommand[@]}"
}

#######################################
# Build a configured Liberty image.
# Arguments:
#   None
#######################################
function buildLibertyConfiguredImage() {
  local dsid_properties_file_path="${ROOT_DIR}/configs/${CONFIG_NAME}/configuration/environment/dsid/dsid.infostore.properties"
  local liberty_configured_classes_folder_path="${IMAGES_DIR}/liberty_ubi_combined/classes"
  local liberty_configured_web_app_files_fodler_path="${IMAGES_DIR}/liberty_ubi_combined/application/web-app-files"

  print "Building Liberty image"

  deleteFolderIfExistsAndCreate "${liberty_configured_classes_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_web_app_files_fodler_path}"

  cp "${dsid_properties_file_path}" "${liberty_configured_classes_folder_path}/DataSource.properties"
  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]] && [[ "${DEPLOYMENT_PATTERN}" != "schema_dev" ]]; then
    sed -i.bak -e '/DataSourceId.*/d' "${liberty_configured_classes_folder_path}/DataSource.properties"
  fi
  echo "AppName=opal-services" >> "${liberty_configured_classes_folder_path}/DataSource.properties"

  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/live/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/server.extensions.xml" "${IMAGES_DIR}/liberty_ubi_combined/"
  cp -r "${LOCAL_CONFIG_DIR}/user.registry.xml" "${IMAGES_DIR}/liberty_ubi_combined/"

  # Copy catalog.json & web.xml specific to the DEPLOYMENT_PATTERN
  cp -r "${TOOLKIT_APPLICATION_DIR}/target-mods/${CATALOGUE_TYPE}/catalog.json" "${liberty_configured_classes_folder_path}"
  cp -r "${TOOLKIT_APPLICATION_DIR}/fragment-mods/${APPLICATION_BASE_TYPE}/WEB-INF/web.xml" "${liberty_configured_web_app_files_fodler_path}/web.xml"
  
  sed -i.bak -e '1s/^/<?xml version="1.0" encoding="UTF-8"?><web-app xmlns="http:\/\/java.sun.com\/xml\/ns\/javaee" xmlns:xsi="http:\/\/www.w3.org\/2001\/XMLSchema-instance" xsi:schemaLocation="http:\/\/java.sun.com\/xml\/ns\/javaee http:\/\/java.sun.com\/xml\/ns\/javaee\/web-app_3_0.xsd" id="WebApp_ID" version="3.0"> <display-name>opal<\/display-name>/' \
    "${liberty_configured_web_app_files_fodler_path}/web.xml"
  echo '</web-app>' >>"${liberty_configured_web_app_files_fodler_path}/web.xml"

  # In the schema_dev deployment point Gateway schemes to the ISTORE schemes
  if [[ "${DEPLOYMENT_PATTERN}" == "schema_dev" ]]; then
    sed -i 's/^SchemaResource=/Gateway.External.SchemaResource=/' "${liberty_configured_classes_folder_path}/ApolloServerSettingsMandatory.properties"
    sed -i 's/^ChartingSchemesResource=/Gateway.External.ChartingSchemesResource=/' "${liberty_configured_classes_folder_path}/ApolloServerSettingsMandatory.properties"
  fi

  docker build \
    -t "${LIBERTY_CONFIGURED_IMAGE_NAME}:${I2A_LIBERTY_CONFIGURED_IMAGE_TAG}" \
    "${IMAGES_DIR}/liberty_ubi_combined" \
    --build-arg "BASE_IMAGE=${LIBERTY_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Build a configured Liberty image.
# Arguments:
#   None
#######################################
function buildLibertyConfiguredImageForPreProd() {
  local dsid_properties_file_path="${LOCAL_CONFIG_DIR}/environment/dsid/dsid.infostore.properties"
  local liberty_configured_classes_folder_path="${IMAGES_DIR}/liberty_ubi_combined/classes"
  local liberty_configured_web_app_files_fodler_path="${IMAGES_DIR}/liberty_ubi_combined/application/web-app-files"

  print "Building Liberty image"
  
  deleteFolderIfExistsAndCreate "${liberty_configured_classes_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_web_app_files_fodler_path}"

  cp "${dsid_properties_file_path}" "${liberty_configured_classes_folder_path}/DataSource.properties"
  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]]; then
    sed -i.bak -e '/DataSourceId.*/d' "${liberty_configured_classes_folder_path}/DataSource.properties"
  fi
  echo "AppName=opal-services" >> "${liberty_configured_classes_folder_path}/DataSource.properties"
  
  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/live/." "${liberty_configured_classes_folder_path}"
  mv "${IMAGES_DIR}/liberty_ubi_combined/classes/server.extensions.xml" "${IMAGES_DIR}/liberty_ubi_combined/"
  cp -r "${LOCAL_CONFIG_DIR}/user.registry.xml" "${IMAGES_DIR}/liberty_ubi_combined/"

  # Copy catalog.json & web.xml specific to the DEPLOYMENT_PATTERN
  cp -pr "${TOOLKIT_APPLICATION_DIR}/target-mods/${CATALOGUE_TYPE}/catalog.json" "${liberty_configured_classes_folder_path}"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/fragment-mods/${APPLICATION_BASE_TYPE}/WEB-INF/web.xml" "${liberty_configured_web_app_files_fodler_path}/web.xml"

  sed -i.bak -e '1s/^/<?xml version="1.0" encoding="UTF-8"?><web-app xmlns="http:\/\/java.sun.com\/xml\/ns\/javaee" xmlns:xsi="http:\/\/www.w3.org\/2001\/XMLSchema-instance" xsi:schemaLocation="http:\/\/java.sun.com\/xml\/ns\/javaee http:\/\/java.sun.com\/xml\/ns\/javaee\/web-app_3_0.xsd" id="WebApp_ID" version="3.0"> <display-name>opal<\/display-name>/' \
    "${liberty_configured_web_app_files_fodler_path}/web.xml"
  echo '</web-app>' >>"${liberty_configured_web_app_files_fodler_path}/web.xml"

  docker build \
    -t "${LIBERTY_CONFIGURED_IMAGE_NAME}:${I2A_LIBERTY_CONFIGURED_IMAGE_TAG}" \
    "${IMAGES_DIR}/liberty_ubi_combined" \
    --build-arg "BASE_IMAGE=${LIBERTY_BASE_IMAGE_NAME}"
}

#######################################
# Run a Load Balancer container.
# Arguments:
#   None
#######################################
function runLoadBalancer() {
  print "Load balancer container ${LOAD_BALANCER_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${LOAD_BALANCER_CONTAINER_NAME}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${I2_ANALYZE_FQDN}" \
    -p "9046:9046" \
    -v "${PRE_PROD_DIR}/load-balancer:/usr/local/etc/haproxy" \
    -v "${LOCAL_KEYS_DIR}/i2analyze:${CONTAINER_SECRETS_DIR}" \
    -e "LIBERTY1_LB_STANZA=${LIBERTY1_LB_STANZA}" \
    -e "LIBERTY2_LB_STANZA=${LIBERTY2_LB_STANZA}" \
    -e "LIBERTY_SSL_CONNECTION=${LIBERTY_SSL_CONNECTION}" \
    -e "SERVER_SSL=true" \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/CA.cer" \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/server.cer" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/server.key" \
    "${LOAD_BALANCER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}


function runExampleConnector() {
  local CONTAINER="$1"
  local FQDN="$2"
  local KEY_FOLDER="$3"
  print "Connector container ${CONTAINER} is starting"
  docker run -m 128m -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${CONNECTOR1_APP_PORT}":3700 \
    -v "${LOCAL_KEYS_DIR}/${KEY_FOLDER}:${CONTAINER_SECRETS_DIR}" \
    -e "SERVER_SSL=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/CA.cer" \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/server.cer" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/server.key" \
    "${CONNECTOR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

function runConnector() {
  local CONTAINER="$1"
  local FQDN="$2"
  local connector_name="$3"
  local connector_image_version="$4"
  print "Connector container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -v "${LOCAL_KEYS_DIR}/${connector_name}:${CONTAINER_SECRETS_DIR}" \
    -e "SERVER_SSL=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/CA.cer" \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/server.cer" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/server.key" \
    "${CONNECTOR_IMAGE_BASE_NAME}${connector_name}:${connector_image_version}"
}

###############################################################################
# End of function definitions                                                 #
###############################################################################
