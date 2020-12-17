#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

###############################################################################
# Start of function definitions                                               #
###############################################################################

function runZK() {
  local CONTAINER=${1}
  local FQDN=${2}
  local DATA_VOLUME=${3}
  local DATALOG_VOLUME=${4}
  local LOG_VOLUME=${5}
  local HOST_PORT=${6}
  local ZOO_ID=${7}
  print "ZooKeeper container ${CONTAINER} is starting"
  docker run --restart always -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${HOST_PORT}:8080" \
    -v "${DATA_VOLUME}:/data" \
    -v "${DATALOG_VOLUME}:/datalog" \
    -v "${LOG_VOLUME}:/logs" \
    -v "${LOCAL_KEYS_DIR}/${CONTAINER}:${CONTAINER_SECRETS_DIR}" \
    -e "ZOO_SERVERS=server.1=${ZK1_FQDN}:2888:3888 server.2=${ZK2_FQDN}:2888:3888 server.3=${ZK3_FQDN}:2888:3888" \
    -e "ZOO_MY_ID=${ZOO_ID}" \
    -e "ZOO_SECURE_CLIENT_PORT=${ZK_SECURE_CLIENT_PORT}" \
    -e "ZOO_CLIENT_PORT=2181" \
    -e "ZOO_4LW_COMMANDS_WHITELIST=ruok, mntr, conf" \
    -e "SERVER_SSL=${SOLR_ZOO_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}"/server.key \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/server.cer \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/CA.cer \
    "${ZOOKEEPER_IMAGE_NAME}"
}

function runSolr() {
  local CONTAINER=${1}
  local FQDN=${2}
  local VOLUME=${3}
  local HOST_PORT=${4}
  print "Solr container ${CONTAINER} is starting"
  docker run -d \
    --name "${CONTAINER}" \
    --net "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    --init \
    -p "${HOST_PORT}":8983 \
    -v "${VOLUME}:/var/solr" \
    -v "${LOCAL_KEYS_DIR}/${CONTAINER}:${CONTAINER_SECRETS_DIR}" \
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
    "${SOLR_IMAGE_NAME}"
}

function runSQLServer() {
  print "SQL Server container ${SQL_SERVER_CONTAINER_NAME} is starting"
  docker run -d \
    --name "${SQL_SERVER_CONTAINER_NAME}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${SQL_SERVER_FQDN}" \
    -p "1433:${DB_PORT}" \
    -v "${SQL_SERVER_VOLUME_NAME}:/var/opt/mssql" \
    -v "${LOCAL_KEYS_DIR}/sqlserver:${CONTAINER_SECRETS_DIR}" \
    -v "${LOCAL_TOOLKIT_DIR}/examples/data:/tmp/examples/data" \
    -e "ACCEPT_EULA=${ACCEPT_EULA}" \
    -e "MSSQL_AGENT_ENABLED=true" \
    -e "MSSQL_PID=${MSSQL_PID}" \
    -e "SA_PASSWORD_FILE=${CONTAINER_SECRETS_DIR}/SA_PASSWORD" \
    -e "SERVER_SSL=${DB_SSL_CONNECTION}" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}"/server.key \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}"/server.cer \
    "${SQL_SERVER_IMAGE_NAME}"
}

function runLiberty() {
  local CONTAINER=${1}
  local FQDN=${2}
  local VOLUME=${3}
  local HOST_PORT=${4}
  local KEY_FOLDER=${5}
  print "Liberty container ${CONTAINER} is starting"
  docker run -m 1g -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${HOST_PORT}:9443" \
    -v "${LOCAL_KEYS_DIR}/${KEY_FOLDER}:${CONTAINER_SECRETS_DIR}" \
    -v "${VOLUME}:/data" \
    -e "LICENSE=${LIC_AGREEMENT}" \
    -e "FRONT_END_URI=${FRONT_END_URI}" \
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
    -e "LIBERTY_HADR_MODE=1" \
    -e "LIBERTY_HADR_POLL_INTERVAL=1" \
    "${LIBERTY_CONFIGURED_IMAGE_NAME}"
}

function buildLibertyConfiguredImage() {
  print "Building Liberty image"
  rm -rf "${IMAGES_DIR}/liberty_ubi_combined/classes"
  mkdir -p "${IMAGES_DIR}/liberty_ubi_combined/classes"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes/." "${IMAGES_DIR}/liberty_ubi_combined/classes"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes/." "${IMAGES_DIR}/liberty_ubi_combined/classes"
  cp -r "${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes/." "${IMAGES_DIR}/liberty_ubi_combined/classes"
  cp -r "${LOCAL_CONFIG_DIR}/live/." "${IMAGES_DIR}/liberty_ubi_combined/classes"
  mv "${IMAGES_DIR}/liberty_ubi_combined/classes/server.extensions.xml" "${IMAGES_DIR}/liberty_ubi_combined/"
  docker build \
    -t "${LIBERTY_CONFIGURED_IMAGE_NAME}" \
    "${IMAGES_DIR}/liberty_ubi_combined" \
    --build-arg "BASE_IMAGE=${LIBERTY_BASE_IMAGE_NAME}"
}

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
    "${LOAD_BALANCER_IMAGE_NAME}"
}

function runExampleConnector() {
  local CONTAINER=${1}
  local FQDN=${2}
  local HOST_PORT=${3}
  print "Connector container ${CONTAINER} is starting"
  docker run -m 128m -d \
    --name "${CONTAINER}" \
    --network "${DOMAIN_NAME}" \
    --net-alias "${FQDN}" \
    -p "${HOST_PORT}":3700 \
    -v "${LOCAL_KEYS_DIR}/${CONTAINER}:${CONTAINER_SECRETS_DIR}" \
    -e "SERVER_SSL=${GATEWAY_SSL_CONNECTION}" \
    -e "SSL_CA_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/CA.cer" \
    -e "SSL_CERTIFICATE_FILE=${CONTAINER_SECRETS_DIR}/server.cer" \
    -e "SSL_PRIVATE_KEY_FILE=${CONTAINER_SECRETS_DIR}/server.key" \
    "${CONNECTOR_IMAGE_NAME}"
}

###############################################################################
# End of function definitions                                                 #
###############################################################################
