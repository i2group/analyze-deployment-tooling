#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

. /opt/environment.sh

# Load secrets if they exist on disk and export them as envs
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'ZOO_DIGEST_PASSWORD'
file_env 'ZOO_DIGEST_USERNAME'
file_env 'SOLR_HTTP_BASIC_AUTH_USER'
file_env 'SOLR_HTTP_BASIC_AUTH_PASSWORD'

TMP_SECRETS="/tmp/i2acerts"

if [[ ${SOLR_ZOO_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} || -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi
  KEY=${TMP_SECRETS}/server.key
  CER=${TMP_SECRETS}/server.cer
  CA_CER=${TMP_SECRETS}/CA.cer
  KEYSTORE=${TMP_SECRETS}/keystore.p12
  TRUSTSTORE=${TMP_SECRETS}/truststore.p12
  KEYSTORE_PASS=$(openssl rand -base64 16)
  export KEYSTORE_PASS

  mkdir ${TMP_SECRETS}
  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  openssl pkcs12 -export -in ${CER} -inkey "${KEY}" -certfile ${CA_CER} -passout env:KEYSTORE_PASS -out "${KEYSTORE}"
  OUTPUT=$(keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file ${CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12 2>&1)
  if [[ "$OUTPUT" != "Certificate was added to keystore" ]]; then
    echo "$OUTPUT"
    exit 1
  fi

  ZOO_SSL_KEY_STORE_LOCATION=${KEYSTORE}
  ZOO_SSL_TRUST_STORE_LOCATION=${TRUSTSTORE}
  ZOO_SSL_KEY_STORE_PASSWORD=${KEYSTORE_PASS}
  ZOO_SSL_TRUST_STORE_PASSWORD=${KEYSTORE_PASS}

  export ZOO_SSL_KEY_STORE_LOCATION
  export ZOO_SSL_TRUST_STORE_LOCATION
  export ZOO_SSL_KEY_STORE_PASSWORD
  export ZOO_SSL_TRUST_STORE_PASSWORD

elif [[ ${DB_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
    exit 1
  fi
  CA_CER=${TMP_SECRETS}/CA.cer
  TRUSTSTORE=${TMP_SECRETS}/truststore.p12
  KEYSTORE_PASS=$(openssl rand -base64 16)
  export KEYSTORE_PASS

  mkdir ${TMP_SECRETS}
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file ${CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12

elif [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  CA_CER="${TMP_SECRETS}/CA.cer"
  # Create a directory if it doesn't exist
  if [[ ! -d "${TMP_SECRETS}" ]]; then
    mkdir "${TMP_SECRETS}"
  fi
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
fi

if [[ ${DB_SSL_CONNECTION} == true ]]; then
  DB_TRUSTSTORE_LOCATION=${TRUSTSTORE}
  DB_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}

  export DB_TRUSTSTORE_LOCATION
  export DB_TRUSTSTORE_PASSWORD
fi

if [[ "${GATEWAY_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_OUTBOUND_PRIVATE_KEY'
  file_env 'SSL_OUTBOUND_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'

  if [[ -z "${SSL_OUTBOUND_PRIVATE_KEY}" || -z "${SSL_OUTBOUND_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi

  GATEWAY_CER="${TMP_SECRETS}/i2Analyze.pem"
  CA_CER="${TMP_SECRETS}/CA.cer"

  # Create a directory if it doesn't exist
  if [[ ! -d "${TMP_SECRETS}" ]]; then
    mkdir "${TMP_SECRETS}"
  fi
  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >>"${GATEWAY_CER}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >>"${GATEWAY_CER}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
fi

set +e
exec "$@"
