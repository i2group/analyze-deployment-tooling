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

set -e

. /opt/environment.sh

function addTrustedCertifcates() {
  local pem_file=$1
  local trust_store=$2
  local cert_count
  
  # shellcheck disable=SC2126
  cert_count=$(grep 'END CERTIFICATE' "${pem_file}"| wc -l)

  # For every cert in the PEM file, extract it and import into the JKS keystore
  # awk command: step 1, if line is in the desired cert, print the line
  #              step 2, increment counter when last line of cert is found
  for N in $(seq 0 $(("${cert_count}" - 1))); do
    alias="${pem_file%.*}-$N" 
    awk "n==$N { print }; /END CERTIFICATE/ { n++ }" "${pem_file}" |
    keytool -noprompt -import -trustcacerts \
            -alias "${alias}" -keystore "${trust_store}" -storepass:env KEYSTORE_PASS -storetype PKCS12
  done
}

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
  TRUST_EXTRA_CER=${TMP_SECRETS}/TRUST_EXTRA.cer

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
  KEYSTORE_PASS=$(openssl rand -base64 16)
  export KEYSTORE_PASS
  keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file ${CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12
  if [[ -n ${SSL_ADDITIONAL_TRUST_CERTIFICATES} && "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" != "None" ]]; then
    echo "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" >"${TRUST_EXTRA_CER}"
    addTrustedCertifcates "${TRUST_EXTRA_CER}" "${TRUSTSTORE}"
  fi

  file_env 'APP_SECRETS'
  if [[ -n "${APP_SECRETS}" && "${APP_SECRETS}" != "None" ]]; then
    while read -r key value; do
      declare -x "$key"="$value"
    done < <(jq -r 'keys[] as $k | "\($k) \(.[$k])"' < <(echo "${APP_SECRETS}"))
  fi
fi

if [[ ${GATEWAY_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_OUTBOUND_PRIVATE_KEY'
  file_env 'SSL_OUTBOUND_CERTIFICATE'
  file_env 'SSL_OUTBOUND_CA_CERTIFICATE'

  if [[ -z ${SSL_OUTBOUND_PRIVATE_KEY} || -z ${SSL_OUTBOUND_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE"
    exit 1
  fi
  OUT_KEY=${TMP_SECRETS}/out_server.key
  OUT_CER=${TMP_SECRETS}/out_server.cer
  OUT_CA_CER=${TMP_SECRETS}/out_CA.cer
  OUT_KEYSTORE=${TMP_SECRETS}/out_keystore.p12
  OUT_TRUSTSTORE=${TMP_SECRETS}/out_truststore.p12

  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >"${OUT_KEY}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >"${OUT_CER}"

  if [[ -n ${SSL_OUTBOUND_CA_CERTIFICATE} ]]; then
    echo "${SSL_OUTBOUND_CA_CERTIFICATE}" >"${OUT_CA_CER}"
    keytool -importcert -noprompt -alias ca -keystore "${OUT_TRUSTSTORE}" -file ${OUT_CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12
    if [[ -n ${SSL_ADDITIONAL_TRUST_CERTIFICATES} && "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" != "None" ]]; then
      echo "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" >"${TRUST_EXTRA_CER}"
      addTrustedCertifcates "${TRUST_EXTRA_CER}" "${OUT_TRUSTSTORE}"
    fi
    LIBERTY_OUT_TRUSTSTORE_LOCATION=${OUT_TRUSTSTORE}
  else
    LIBERTY_OUT_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  fi

  openssl pkcs12 -export -in ${OUT_CER} -inkey "${OUT_KEY}" -certfile ${CA_CER} -passout env:KEYSTORE_PASS -out "${OUT_KEYSTORE}"

  LIBERTY_OUT_KEYSTORE_LOCATION=${OUT_KEYSTORE}
  LIBERTY_OUT_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}
  LIBERTY_OUT_KEYSTORE_PASSWORD=${KEYSTORE_PASS}

  export LIBERTY_OUT_TRUSTSTORE_LOCATION
  export LIBERTY_OUT_KEYSTORE_LOCATION
  export LIBERTY_OUT_TRUSTSTORE_PASSWORD
  export LIBERTY_OUT_KEYSTORE_PASSWORD

  LIBERTY_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  LIBERTY_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}

  export LIBERTY_TRUSTSTORE_LOCATION
  export LIBERTY_TRUSTSTORE_PASSWORD
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
  LIBERTY_SSL="true"
  export LIBERTY_SSL
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

/opt/create-connector-config.sh

# Call original liberty entrypoint
exec "/opt/ibm/helpers/runtime/docker-server.sh" "$@"
