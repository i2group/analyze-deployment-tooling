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
  SERVER_KEY=${TMP_SECRETS}/server.key
  SERVER_CER=${TMP_SECRETS}/server.cer

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
  echo "${SSL_PRIVATE_KEY}" >"${SERVER_KEY}"
  echo "${SSL_CERTIFICATE}" >"${SERVER_CER}"
fi

echo '{
  "https": '"${SSL_ENABLED}"',
  "keyFileName": "'"${SERVER_KEY}"'",
  "keyPassphrase": "",
  "certificateFileName": "'"${SERVER_CER}"'",
  "certificateAuthorityFileName": "'"${CA_CER}"'",
  "gatewayCN": "gateway.user"
}' >security-config.json

export PORT=3443

exec "$@"
