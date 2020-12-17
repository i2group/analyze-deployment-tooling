#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

. /opt/environment.sh

DEFAULT_SERVER_DIR=/opt/ibm/wlp/usr/servers/defaultServer
DB_NAME="ISTORE"

# Load secrets if they exist on disk and export them as envs
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'ZOO_DIGEST_PASSWORD'
file_env 'ZOO_DIGEST_USERNAME'
file_env 'SOLR_HTTP_BASIC_AUTH_USER'
file_env 'SOLR_HTTP_BASIC_AUTH_PASSWORD'

if [[ ${SERVER_SSL} == true || ${SOLR_ZOO_SSL_CONNECTION} == true || ${GATEWAY_SSL_CONNECTION} == true || ${DB_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
    exit 1
  fi
  
  TMP_SECRETS=/tmp/i2acerts
  CA_CER=${TMP_SECRETS}/CA.cer
  TRUSTSTORE=${TMP_SECRETS}/truststore.p12

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
  KEYSTORE_PASS=$(openssl rand -base64 16)
  export KEYSTORE_PASS
  keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file ${CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12
fi

if [[ ${GATEWAY_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_OUTBOUND_PRIVATE_KEY'
  file_env 'SSL_OUTBOUND_CERTIFICATE'
  
  if [[ -z ${SSL_OUTBOUND_PRIVATE_KEY} || -z ${SSL_OUTBOUND_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE"
    exit 1
  fi
  OUT_KEY=${TMP_SECRETS}/out_server.key
  OUT_CER=${TMP_SECRETS}/out_server.cer
  OUT_KEYSTORE=${TMP_SECRETS}/out_keystore.p12

  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >"${OUT_KEY}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >"${OUT_CER}"

  openssl pkcs12 -export -in ${OUT_CER} -inkey "${OUT_KEY}" -certfile ${CA_CER} -passout env:KEYSTORE_PASS -out "${OUT_KEYSTORE}"

  LIBERTY_OUT_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  LIBERTY_OUT_KEYSTORE_LOCATION=${OUT_KEYSTORE}
  LIBERTY_OUT_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}
  LIBERTY_OUT_KEYSTORE_PASSWORD=${KEYSTORE_PASS}

  export LIBERTY_OUT_TRUSTSTORE_LOCATION
  export LIBERTY_OUT_KEYSTORE_LOCATION
  export LIBERTY_OUT_TRUSTSTORE_PASSWORD
  export LIBERTY_OUT_KEYSTORE_PASSWORD
fi

if [[ ${SERVER_SSL} == true || ${SOLR_ZOO_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} || -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE"
    exit 1
  fi
  KEY=${TMP_SECRETS}/server.key
  CER=${TMP_SECRETS}/server.cer
  KEYSTORE=${TMP_SECRETS}/keystore.p12

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  openssl pkcs12 -export -in ${CER} -inkey "${KEY}" -certfile ${CA_CER} -passout env:KEYSTORE_PASS -out "${KEYSTORE}"

  LIBERTY_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  LIBERTY_KEYSTORE_LOCATION=${KEYSTORE}
  LIBERTY_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}
  LIBERTY_KEYSTORE_PASSWORD=${KEYSTORE_PASS}

  export LIBERTY_TRUSTSTORE_LOCATION
  export LIBERTY_KEYSTORE_LOCATION
  export LIBERTY_TRUSTSTORE_PASSWORD
  export LIBERTY_KEYSTORE_PASSWORD
fi

if [[ ${SERVER_SSL} == true ]]; then
  LIBERTY_SSL="true"
  HTTP_PORT="-1"
  HTTPS_PORT="9443"
  export LIBERTY_SSL
else
  HTTP_PORT="9080"
  HTTPS_PORT="-1"
fi
export HTTP_PORT
export HTTPS_PORT

if [[ ${DB_SSL_CONNECTION} == true ]]; then
  DB_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  DB_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}

  export DB_TRUSTSTORE_LOCATION
  export DB_TRUSTSTORE_PASSWORD
fi

BOOSTRAP_FILE="${DEFAULT_SERVER_DIR}/bootstrap.properties"
  {
    echo "ApolloServerSettingsResource=ApolloServerSettingsConfigurationSet.properties"
    echo "APOLLO_DATA=${APOLLO_DATA_DIR}"
    echo "apollo.log.dir=${LOG_DIR}"

  } >>"${BOOSTRAP_FILE}"

DISCO_FILESTORE_LOCATION="${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes/DiscoFileStoreLocation.properties"
  {
    echo "FileStoreLocation.chart-store=${APOLLO_DATA_DIR}/chart/main"
    echo "FileStoreLocation.job-store=${APOLLO_DATA_DIR}/job/main"
    echo "FileStoreLocation.recordgroup-store=${APOLLO_DATA_DIR}/recordgroup/main"

  } >>"${DISCO_FILESTORE_LOCATION}"

export DB_NAME

rm -f /opt/ibm/wlp/usr/servers/defaultServer/server.env 
rm -rf /opt/ibm/wlp/usr/servers/defaultServer/configDropins/defaults

# Call original liberty entrypoint
exec "/opt/ibm/helpers/runtime/docker-server.sh" "$@"
