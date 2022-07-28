#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

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
#   6. Zoo ID (an identifier for the ZooKeeper server)
#   7. ZK secret location
#   8. ZK secret volume
#######################################
function runZK() {
  local CONTAINER="$1"
  local FQDN="$2"
  local DATA_VOLUME="$3"
  local DATALOG_VOLUME="$4"
  local LOG_VOLUME="$5"
  local ZOO_ID="$6"
  local SECRET_LOCATION="$7"
  local SECRETS_VOLUME="$8"

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/${SECRET_LOCATION}/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/${SECRET_LOCATION}/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  print "ZooKeeper container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -v "${DATA_VOLUME}:/data" \
    -v "${DATALOG_VOLUME}:/datalog" \
    -v "${LOG_VOLUME}:/logs" \
    -v "${SECRETS_VOLUME}:${CONTAINER_SECRETS_DIR}" \
    -e "ZOO_SERVERS=${ZOO_SERVERS}" \
    -e "ZOO_MY_ID=${ZOO_ID}" \
    -e "ZOO_SECURE_CLIENT_PORT=${ZK_SECURE_CLIENT_PORT}" \
    -e "ZOO_CLIENT_PORT=2181" \
    -e "ZOO_4LW_COMMANDS_WHITELIST=ruok, mntr, conf" \
    -e "ZOO_MAX_CLIENT_CNXNS=100" \
    -e "SERVER_SSL=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    "${ZOOKEEPER_IMAGE_NAME}:${ZOOKEEPER_VERSION}"
}

#######################################
# Run a Solr server container.
# Arguments:
#   1. Solr container name
#   2. Solr container FQDN
#   3. Solr volume name
#   4. Solr port (on the host machine)
#   5. Solr secret location
#   6. Solr secret volume
#######################################
function runSolr() {
  local CONTAINER="$1"
  local FQDN="$2"
  local VOLUME="$3"
  local HOST_PORT="$4"
  local SECRET_LOCATION="$5"
  local SECRETS_VOLUME="$6"

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/${SECRET_LOCATION}/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/${SECRET_LOCATION}/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  local zk_digest_password
  zk_digest_password=$(getSecret "solr/ZK_DIGEST_PASSWORD")
  local zk_digest_readonly_password
  zk_digest_readonly_password=$(getSecret "solr/ZK_DIGEST_READONLY_PASSWORD")

  print "Solr container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    --init \
    -p "${HOST_PORT}":8983 \
    -v "${VOLUME}:/var/solr" \
    -v "${SOLR_BACKUP_VOLUME_NAME}:${SOLR_BACKUP_VOLUME_LOCATION}" \
    -v "${SECRETS_VOLUME}:${CONTAINER_SECRETS_DIR}" \
    -e SOLR_OPTS="-Dsolr.allowPaths=${SOLR_BACKUP_VOLUME_LOCATION}" \
    -e "ZK_HOST=${ZK_HOST}" \
    -e "SOLR_HOST=${FQDN}" \
    -e "ZOO_DIGEST_USERNAME=${ZK_DIGEST_USERNAME}" \
    -e "ZOO_DIGEST_PASSWORD=${zk_digest_password}" \
    -e "ZOO_DIGEST_READONLY_USERNAME=${ZK_DIGEST_READONLY_USERNAME}" \
    -e "ZOO_DIGEST_READONLY_PASSWORD=${zk_digest_readonly_password}" \
    -e "SOLR_ZOO_SSL_CONNECTION=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SERVER_SSL=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a SQL Server container.
# Arguments:
#   None
#######################################
function runSQLServer() {
  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/sqlserver/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/sqlserver/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  local sa_initial_password
  sa_initial_password=$(getSecret "sqlserver/sa_INITIAL_PASSWORD")

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  print "SQL Server container ${SQL_SERVER_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${SQL_SERVER_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${SQL_SERVER_FQDN}" \
    -p "${HOST_PORT_DB}:1433" \
    -v "${SQL_SERVER_VOLUME_NAME}:/var/opt/mssql" \
    -v "${SQL_SERVER_BACKUP_VOLUME_NAME}:${DB_CONTAINER_BACKUP_DIR}" \
    -v "${SQL_SERVER_SECRETS_VOLUME_NAME}:${CONTAINER_SECRETS_DIR}" \
    -v "${I2A_DATA_SERVER_VOLUME_NAME}:${container_data_dir}" \
    -e "ACCEPT_EULA=${ACCEPT_EULA}" \
    -e "MSSQL_AGENT_ENABLED=true" \
    -e "MSSQL_PID=${MSSQL_PID}" \
    -e "SA_PASSWORD=${sa_initial_password}" \
    -e "SERVER_SSL=${DB_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    "${SQL_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a Db2 Server container.
# Arguments:
#   None
#######################################
function runDb2Server() {
  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/db2server/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/db2server/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  local db2inst1_initial_password
  db2inst1_initial_password=$(getSecret "db2server/db2inst1_INITIAL_PASSWORD")

  local container_data_dir="/var/i2a-data"
  updateVolume "${DATA_DIR}" "${I2A_DATA_SERVER_VOLUME_NAME}" "${container_data_dir}"

  print "Db2 Server container ${DB2_SERVER_CONTAINER_NAME} is starting"
  docker run -d \
    --privileged=true \
    --name "${DB2_SERVER_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${DB2_SERVER_FQDN}" \
    -p "${HOST_PORT_DB}:50000" \
    -v "${DB2_SERVER_BACKUP_VOLUME_NAME}:${DB_CONTAINER_BACKUP_DIR}" \
    -v "${DB2_SERVER_SECRETS_VOLUME_NAME}:${CONTAINER_SECRETS_DIR}" \
    -v "${DB2_SERVER_VOLUME_NAME}:/database/data" \
    -v "${I2A_DATA_SERVER_VOLUME_NAME}:${container_data_dir}" \
    -e "LICENSE=${DB2_LICENSE}" \
    -e "DB_INSTALL_DIR=${DB_INSTALL_DIR}" \
    -e "DB2INST1_PASSWORD=${db2inst1_initial_password}" \
    -e "SERVER_SSL=${DB_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    "${DB2_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
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
  local SECRET_VOLUME="$4"
  local HOST_PORT="$5"
  local KEY_FOLDER="$6"
  local DEBUG_PORT="$7"

  local libertyStartCommand=()
  local dbEnvironment=("-e" "DB_DIALECT=${DB_DIALECT}" "-e" "DB_PORT=${DB_PORT}")
  local runInDebug

  if [[ ${DEBUG_LIBERTY_SERVERS[*]} =~ (^|[[:space:]])"${CONTAINER}"($|[[:space:]]) ]]; then
    runInDebug=true
  else
    runInDebug=false
  fi

  local ssl_outbound_private_key
  ssl_outbound_private_key=$(getSecret "certificates/gateway_user/server.key")
  local ssl_certificate
  ssl_outbound_certificate=$(getSecret "certificates/gateway_user/server.cer")
  local ssl_ca_certificate
  ssl_outbound_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  local zk_digest_password
  zk_digest_password=$(getSecret "solr/ZK_DIGEST_PASSWORD")

  local solr_application_digest_password
  solr_application_digest_password=$(getSecret "solr/SOLR_APPLICATION_DIGEST_PASSWORD")

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/${KEY_FOLDER}/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/${KEY_FOLDER}/server.cer")
  local ssl_ca_certificate

  if [[ "${ENVIRONMENT}" == "config-dev" ]]; then
    if [[ "${AWS_SECRETS}" == "true" ]]; then
      if isSecret "i2a/app-secrets"; then
        app_secrets=$(getSecret "i2a/app-secrets")
      fi
    elif [[ -f "${LOCAL_USER_CONFIG_DIR}/secrets/app-secrets.json" ]]; then
      app_secrets=$(cat "${LOCAL_USER_CONFIG_DIR}/secrets/app-secrets.json")
    else
      app_secrets="None"
    fi

    if [[ "${AWS_SECRETS}" == "true" ]]; then
      if isSecret "i2a/additional-trust-certificates"; then
        ssl_additional_trust_certificates=$(getSecret "i2a/additional-trust-certificates")
      fi
    elif [[ -f "${LOCAL_USER_CONFIG_DIR}"/secrets/additional-trust-certificates.cer ]]; then
      ssl_additional_trust_certificates=$(cat "${LOCAL_USER_CONFIG_DIR}"/secrets/additional-trust-certificates.cer)
    fi

    ssl_ca_certificate=$(getSecret "certificates/externalCA/CA.cer")
  else
    ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")
  fi

  local db_password
  case "${DB_DIALECT}" in
  db2)
    db_password=$(getSecret "db2server/db2inst1_PASSWORD")
    dbEnvironment+=("-e" "DB_SERVER=${DB2_SERVER_FQDN}")
    dbEnvironment+=("-e" "DB_NODE=${DB_NODE}")
    dbEnvironment+=("-e" "DB_USERNAME=${DB2INST1_USERNAME}")
    ;;
  sqlserver)
    db_password=$(getSecret "sqlserver/i2analyze_PASSWORD")
    dbEnvironment+=("-e" "DB_SERVER=${SQL_SERVER_FQDN}")
    dbEnvironment+=("-e" "DB_NODE=${DB_NODE}")
    dbEnvironment+=("-e" "DB_USERNAME=${I2_ANALYZE_USERNAME}")
    ;;
  esac
  dbEnvironment+=("-e" "DB_PASSWORD=${db_password}")

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
  if [[ "${ENVIRONMENT}" == "config-dev" && -f "${CONNECTOR_IMAGES_DIR}/connector-url-mappings-file.json" ]]; then
    CONNECTOR_URL_MAP=$(cat "${CONNECTOR_IMAGES_DIR}"/connector-url-mappings-file.json)
  fi

  if [[ "${LIBERTY_SSL_CONNECTION}" == "true" ]]; then
    CONTAINER_PORT="9443"
  else
    CONTAINER_PORT="9080"
  fi

  docker run -m 2g -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    -v "${SECRET_VOLUME}:${CONTAINER_SECRETS_DIR}" \
    -v "${VOLUME}:/data" \
    -e "LICENSE=${LIC_AGREEMENT}" \
    "${dbEnvironment[@]}" \
    -e "ZK_HOST=${ZK_MEMBERS}" \
    -e "ZOO_DIGEST_USERNAME=${ZK_DIGEST_USERNAME}" \
    -e "ZOO_DIGEST_PASSWORD=${zk_digest_password}" \
    -e "SOLR_HTTP_BASIC_AUTH_USER=${SOLR_APPLICATION_DIGEST_USERNAME}" \
    -e "SOLR_HTTP_BASIC_AUTH_PASSWORD=${solr_application_digest_password}" \
    -e "DB_SSL_CONNECTION=${DB_SSL_CONNECTION}" \
    -e "SOLR_ZOO_SSL_CONNECTION=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SERVER_SSL=${LIBERTY_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    -e "APP_SECRETS=${app_secrets}" \
    -e "SSL_ADDITIONAL_TRUST_CERTIFICATES=${ssl_additional_trust_certificates}" \
    -e "GATEWAY_SSL_CONNECTION=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_OUTBOUND_PRIVATE_KEY=${ssl_outbound_private_key}" \
    -e "SSL_OUTBOUND_CERTIFICATE=${ssl_outbound_certificate}" \
    -e "SSL_OUTBOUND_CA_CERTIFICATE=${ssl_outbound_ca_certificate}" \
    -e "LIBERTY_HADR_MODE=1" \
    -e "LIBERTY_HADR_POLL_INTERVAL=1" \
    -e "CONNECTOR_URL_MAP=${CONNECTOR_URL_MAP}" \
    "${libertyStartCommand[@]}"
}

function createDataSourceProperties() {
  local folder_path="${1}"
  local datasource_properties_file_path="${folder_path}/DataSource.properties"
  local dsid_properties_file_path
  local topology_id
  local datasource_name

  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]]; then
    topology_id="infostore"
  else
    topology_id="opalDAOD"
  fi
  dsid_properties_file_path="${LOCAL_CONFIG_DIR}/environment/dsid/dsid.${topology_id}.properties"
  cp "${dsid_properties_file_path}" "${datasource_properties_file_path}"

  addDataSourcePropertiesIfNecessary "${datasource_properties_file_path}"

  if [[ "${DEPLOYMENT_PATTERN}" != "i2c" ]] && [[ "${DEPLOYMENT_PATTERN}" != "schema_dev" ]]; then
    sed -i.bak -e '/DataSourceId.*/d' "${datasource_properties_file_path}"
  fi
  if ! grep -xq "IsMonitored=.*" "${datasource_properties_file_path}"; then
    addToPropertiesFile "IsMonitored=true" "${datasource_properties_file_path}"
  fi

  addToPropertiesFile "AppName=opal-services" "${datasource_properties_file_path}"
}

#######################################
# Build a configured Liberty image.
# Arguments:
#   None
#######################################
function buildLibertyConfiguredImage() {
  local liberty_configured_path="${IMAGES_DIR}/liberty_ubi_combined"
  local liberty_configured_classes_folder_path="${liberty_configured_path}/classes"
  local liberty_configured_lib_folder_path="${liberty_configured_path}/lib"
  local liberty_configured_web_app_files_fodler_path="${liberty_configured_path}/application/web-app-files"
  local extension_references_file="${LOCAL_USER_CONFIG_DIR}/extension-references.json"
  local extension_dependencies_path="${EXTENSIONS_DIR}/extension-dependencies.json"

  print "Building Liberty image"

  deleteFolderIfExistsAndCreate "${liberty_configured_classes_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_lib_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_web_app_files_fodler_path}"

  createDataSourceProperties "${liberty_configured_classes_folder_path}"

  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/live/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/user.registry.xml" "${liberty_configured_path}/"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/privacyagreement.html" "${liberty_configured_path}/"

  # Copy extensions to the liberty image
  deleteFolderIfExistsAndCreate "${liberty_configured_lib_folder_path}"
  readarray -t extension_files < <(jq -r '.extensions[] | .name + "-" + .version' <"${extension_references_file}")
  createFolder "${PREVIOUS_CONFIGURATION_DIR}/lib"
  for extension in "${extension_files[@]}"; do
    # shellcheck disable=SC2001
    extension_name=$(echo "${extension}" | sed 's|\(.*\)-.*|\1|')
    if [[ ! -f "${EXTENSIONS_DIR}/${extension_name}/target/${extension}.jar" ]]; then
      echo "Extension does NOT exist: ${EXTENSIONS_DIR}/${extension_name}/target/${extension}.jar"
      continue
    fi
    # Copy dependencies of the extension
    IFS=' ' read -ra dependencies <<<"$(jq -r --arg name "${extension_name}" '.[] | select(.name == $name) | .dependencies[]' "${extension_dependencies_path}" | xargs)"
    for dependency_name in "${dependencies[@]}"; do
      local dependency_version
      dependency_version="$(xmlstarlet sel -t -v "/project/version" "${EXTENSIONS_DIR}/${dependency_name}/pom.xml")"
      cp "${EXTENSIONS_DIR}/${dependency_name}/target/${dependency_name}-${dependency_version}.jar" "${liberty_configured_lib_folder_path}"
      cp -p "${PREVIOUS_EXTENSIONS_DIR}/${dependency_name}.sha512" "${PREVIOUS_CONFIGURATION_DIR}/lib"
    done
    # Copy the extension
    cp "${EXTENSIONS_DIR}/${extension_name}/target/${extension}.jar" "${liberty_configured_lib_folder_path}"
    cp -p "${PREVIOUS_EXTENSIONS_DIR}/${extension_name}.sha512" "${PREVIOUS_CONFIGURATION_DIR}/lib"
  done

  # Copy server extensions
  if [[ -f "${LOCAL_CONFIG_DIR}/server.extensions.xml" ]]; then
    cp -r "${LOCAL_CONFIG_DIR}/server.extensions.xml" "${liberty_configured_path}/"
  else
    echo '<?xml version="1.0" encoding="UTF-8"?><server/>' >"${liberty_configured_path}/server.extensions.xml"
  fi
  if [[ "${EXTENSIONS_DEV}" == true ]]; then
    cp -r "${LOCAL_CONFIG_DIR}/server.extensions.dev.xml" "${liberty_configured_path}/"
  else
    echo '<?xml version="1.0" encoding="UTF-8"?><server/>' >"${liberty_configured_path}/server.extensions.dev.xml"
  fi

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
  local liberty_configured_path="${IMAGES_DIR}/liberty_ubi_combined"
  local liberty_configured_classes_folder_path="${liberty_configured_path}/classes"
  local liberty_configured_lib_folder_path="${liberty_configured_path}/lib"
  local liberty_configured_web_app_files_fodler_path="${liberty_configured_path}/application/web-app-files"

  print "Building Liberty image"

  deleteFolderIfExistsAndCreate "${liberty_configured_classes_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_lib_folder_path}"
  deleteFolderIfExistsAndCreate "${liberty_configured_web_app_files_fodler_path}"

  createDataSourceProperties "${liberty_configured_classes_folder_path}"

  # Updating mpMetrics authentication value
  xmlstarlet edit -L --update "/server/mpMetrics/@authentication" \
    --value "${LIBERTY_SSL_CONNECTION}" \
    "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/server.extensions.xml"

  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${liberty_configured_classes_folder_path}"
  cp -r "${LOCAL_CONFIG_DIR}/live/." "${liberty_configured_classes_folder_path}"
  mv "${liberty_configured_classes_folder_path}/server.extensions.xml" "${liberty_configured_path}/"
  cp -r "${LOCAL_CONFIG_DIR}/user.registry.xml" "${liberty_configured_path}/"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/privacyagreement.html" "${liberty_configured_path}/"

  # Copy catalog.json & web.xml specific to the DEPLOYMENT_PATTERN
  cp -pr "${TOOLKIT_APPLICATION_DIR}/target-mods/${CATALOGUE_TYPE}/catalog.json" "${liberty_configured_classes_folder_path}"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/fragment-mods/${APPLICATION_BASE_TYPE}/WEB-INF/web.xml" "${liberty_configured_web_app_files_fodler_path}/web.xml"

  sed -i.bak -e '1s/^/<?xml version="1.0" encoding="UTF-8"?><web-app xmlns="http:\/\/java.sun.com\/xml\/ns\/javaee" xmlns:xsi="http:\/\/www.w3.org\/2001\/XMLSchema-instance" xsi:schemaLocation="http:\/\/java.sun.com\/xml\/ns\/javaee http:\/\/java.sun.com\/xml\/ns\/javaee\/web-app_3_0.xsd" id="WebApp_ID" version="3.0"> <display-name>opal<\/display-name>/' \
    "${liberty_configured_web_app_files_fodler_path}/web.xml"
  echo '</web-app>' >>"${liberty_configured_web_app_files_fodler_path}/web.xml"

  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><server>
    <featureManager>
        <feature>restConnector-2.0</feature>
    </featureManager>
    <administrator-role>
        <user>${I2_ANALYZE_ADMIN}</user>
    </administrator-role>
  </server>" >"${IMAGES_DIR}/liberty_ubi_combined/server.extensions.dev.xml"

  docker build \
    -t "${LIBERTY_CONFIGURED_IMAGE_NAME}:${I2A_LIBERTY_CONFIGURED_IMAGE_TAG}" \
    "${IMAGES_DIR}/liberty_ubi_combined" \
    --build-arg "BASE_IMAGE=${LIBERTY_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

#######################################
# Run a Load Balancer container.
# Arguments:
#   None
#######################################
function runLoadBalancer() {
  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/i2analyze/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/i2analyze/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  local load_balancer_config_dir="/usr/local/etc/haproxy"
  updateVolume "${PRE_PROD_DIR}/load-balancer" "${LOAD_BALANCER_VOLUME_NAME}" "${load_balancer_config_dir}"

  print "Load balancer container ${LOAD_BALANCER_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${LOAD_BALANCER_CONTAINER_NAME}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${I2_ANALYZE_FQDN}" \
    -p "9046:9046" \
    -v "${LOAD_BALANCER_VOLUME_NAME}:${load_balancer_config_dir}" \
    -v "${LOAD_BALANCER_SECRETS_VOLUME_NAME}:${CONTAINER_SECRETS_DIR}" \
    -e "LIBERTY1_LB_STANZA=${LIBERTY1_LB_STANZA}" \
    -e "LIBERTY2_LB_STANZA=${LIBERTY2_LB_STANZA}" \
    -e "LIBERTY_SSL_CONNECTION=${LIBERTY_SSL_CONNECTION}" \
    -e "LIBERTY_SSL=${LIBERTY_SSL}" \
    -e "SERVER_SSL=true" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    "${LOAD_BALANCER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

function runExampleConnector() {
  local CONTAINER="$1"
  local FQDN="$2"
  local KEY_FOLDER="$3"
  local SECRET_VOLUME="$4"

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/${KEY_FOLDER}/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/${KEY_FOLDER}/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  print "Connector container ${CONTAINER} is starting"
  docker run -m 128m -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -v "${SECRET_VOLUME}:${CONTAINER_SECRETS_DIR}" \
    -e "SSL_ENABLED=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    "${CONNECTOR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"
}

function runConnector() {
  local CONTAINER="$1"
  local FQDN="$2"
  local connector_name="$3"
  local connector_tag="$4"
  local connector_path="${connector_name}"

  if [[ "${AWS_SECRETS}" == "true" ]]; then
    connector_path="${connector_name}-${connector_tag}"
  fi

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/${connector_path}/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/${connector_path}/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  print "Connector container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -v "${connector_name}_secrets:${CONTAINER_SECRETS_DIR}" \
    -e "CONNECTOR_ID=${connector_name}" \
    -e "SSL_ENABLED=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY=${ssl_private_key}" \
    -e "SSL_CERTIFICATE=${ssl_certificate}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    -e "SSL_GATEWAY_CN=${I2_GATEWAY_USERNAME}" \
    -e "SSL_SERVER_PORT=3443" \
    "${CONNECTOR_IMAGE_BASE_NAME}${connector_name}:${connector_tag}"
}

function runPrometheus() {
  local prometheus_config_dir="/etc/prometheus"
  local prometheus_tmp_config_dir="/tmp/prometheus"
  local prometheus_start_command=()

  local prometheus_password
  prometheus_password=$(getPrometheusAdminPassword)
  local liberty_admin_password
  liberty_admin_password=$(getApplicationAdminPassword)

  local ssl_private_key
  ssl_private_key=$(getSecret "certificates/prometheus/server.key")
  local ssl_certificate
  ssl_certificate=$(getSecret "certificates/prometheus/server.cer")
  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/externalCA/CA.cer")

  local ssl_outbound_private_key
  ssl_outbound_private_key=$(getSecret "certificates/gateway_user/server.key")
  local ssl_certificate
  ssl_outbound_certificate=$(getSecret "certificates/gateway_user/server.cer")
  local ssl_ca_certificate
  ssl_outbound_ca_certificate=$(getSecret "certificates/CA/CA.cer")

  if [[ "${ENVIRONMENT}" == "config-dev" ]]; then
    prometheus_start_command+=("-e" "PROMETHEUS_USERNAME=${PROMETHEUS_USERNAME}")
    prometheus_start_command+=("-e" "PROMETHEUS_PASSWORD=${prometheus_password}")
    prometheus_start_command+=("-e" "LIBERTY_ADMIN_USERNAME=${I2_ANALYZE_ADMIN}")
    prometheus_start_command+=("-e" "LIBERTY_ADMIN_PASSWORD=${liberty_admin_password}")
    prometheus_start_command+=("-e" "LIBERTY_SSL_CONNECTION=${LIBERTY_SSL_CONNECTION}")
    prometheus_start_command+=("-e" "SERVER_SSL=${PROMETHEUS_SSL_CONNECTION}")
    prometheus_start_command+=("-e" "SSL_PRIVATE_KEY=${ssl_private_key}")
    prometheus_start_command+=("-e" "SSL_CERTIFICATE=${ssl_certificate}")
    prometheus_start_command+=("-e" "SSL_CA_CERTIFICATE=${ssl_ca_certificate}")
    prometheus_start_command+=("-e" "SSL_OUTBOUND_PRIVATE_KEY=${ssl_outbound_private_key}")
    prometheus_start_command+=("-e" "SSL_OUTBOUND_CERTIFICATE=${ssl_outbound_certificate}")
    prometheus_start_command+=("-e" "SSL_OUTBOUND_CA_CERTIFICATE=${ssl_outbound_ca_certificate}")
  fi

  checkFileExists "${LOCAL_PROMETHEUS_CONFIG_DIR}/prometheus.yml"
  updateVolume "${LOCAL_PROMETHEUS_CONFIG_DIR}" "${PROMETHEUS_CONFIG_VOLUME_NAME}" "${prometheus_tmp_config_dir}"

  print "Prometheus container ${PROMETHEUS_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${PROMETHEUS_CONTAINER_NAME}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${PROMETHEUS_FQDN}" \
    -p "${HOST_PORT_PROMETHEUS}:9090" \
    -v "${PROMETHEUS_CONFIG_VOLUME_NAME}:${prometheus_tmp_config_dir}" \
    -v "${PROMETHEUS_DATA_VOLUME_NAME}:/prometheus" \
    -v "${PROMETHEUS_SECRETS_VOLUME_NAME}:${CONTAINER_SECRETS_DIR}" \
    "${prometheus_start_command[@]}" \
    "${PROMETHEUS_IMAGE_NAME}:${PROMETHEUS_VERSION}"
}

function runGrafana() {
  local grafana_provisioning_dir="/etc/grafana/provisioning"
  local grafana_provisioning_datasources_dir="/etc/grafana/provisioning/datasources"
  local grafana_dashboards_dir="/etc/grafana/dashboards"
  updateVolume "${LOCAL_GRAFANA_CONFIG_DIR}/provisioning" "${GRAFANA_PROVISIONING_VOLUME_NAME}" "${grafana_provisioning_dir}"
  updateGrafanaDashboardVolume

  local grafana_password
  grafana_password=$(getSecret "grafana/admin_PASSWORD")

  local prometheus_password
  prometheus_password=$(getPrometheusAdminPassword)

  local ssl_ca_certificate
  ssl_ca_certificate=$(getSecret "certificates/externalCA/CA.cer")

  local prometheus_scheme="http"
  if [[ "${PROMETHEUS_SSL_CONNECTION}" == "true" ]]; then
    prometheus_scheme="https"
  fi
  local prometheus_url="${prometheus_scheme}://${PROMETHEUS_FQDN}:9090"

  print "Grafana container ${GRAFANA_CONTAINER_NAME} is starting"
  docker run -d \
    -p "${HOST_PORT_GRAFANA}:3000" \
    --name="${GRAFANA_CONTAINER_NAME}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${GRAFANA_FQDN}" \
    -v "${GRAFANA_DATA_VOLUME_NAME}:/var/lib/grafana" \
    -v "${GRAFANA_DASHBOARDS_VOLUME_NAME}:${grafana_dashboards_dir}" \
    -v "${GRAFANA_PROVISIONING_VOLUME_NAME}:${grafana_provisioning_dir}" \
    -v "${GRAFANA_SECRETS_VOLUME_NAME}:${CONTAINER_SECRETS_DIR}" \
    -e "GF_SECURITY_ADMIN_USER=${GRAFANA_USERNAME}" \
    -e "GF_SECURITY_ADMIN_PASSWORD=${grafana_password}" \
    -e "GF_SERVER_PROTOCOL=https" \
    -e "GF_SERVER_CERT_FILE=/run/secrets/server.cer" \
    -e "GF_SERVER_CERT_KEY=/run/secrets/server.key" \
    -e "PROMETHEUS_URL=${prometheus_url}" \
    -e "PROMETHEUS_USERNAME=${PROMETHEUS_USERNAME}" \
    -e "PROMETHEUS_PASSWORD=${prometheus_password}" \
    -e "SSL_CA_CERTIFICATE=${ssl_ca_certificate}" \
    "${GRAFANA_IMAGE_NAME}:${GRAFANA_VERSION}"
}

###############################################################################
# End of function definitions                                                 #
###############################################################################
