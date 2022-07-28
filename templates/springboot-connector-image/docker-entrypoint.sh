#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

. /opt/environment.sh

if [[ ${SSL_ENABLED} == true ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_PRIVATE_KEY'
  if [[ -z ${SSL_CA_CERTIFICATE} || -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} ]]; then
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

  KEY=${TMP_SECRETS}/server.key
  CER=${TMP_SECRETS}/server.cer
  KEYSTORE=${TMP_SECRETS}/keystore.p12

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  openssl pkcs12 -export -in ${CER} -inkey "${KEY}" -certfile ${CA_CER} -passout env:KEYSTORE_PASS -out "${KEYSTORE}"

  SERVER_SSL_TRUST_STORE=${TRUSTSTORE}
  SERVER_SSL_KEY_STORE=${KEYSTORE}
  SERVER_SSL_TRUST_STORE_PASSWORD=${KEYSTORE_PASS}
  SERVER_SSL_KEY_STORE_PASSWORD=${KEYSTORE_PASS}

  export SERVER_SSL_TRUST_STORE
  export SERVER_SSL_KEY_STORE
  export SERVER_SSL_TRUST_STORE_PASSWORD
  export SERVER_SSL_KEY_STORE_PASSWORD
fi

export SERVER_PORT=3443

unset SSL_ENABLED
echo "$@"

exec "$@"
