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


if [[ ${SERVER_SSL} == true ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_PRIVATE_KEY'
  if [[ -z ${SSL_CA_CERTIFICATE} || -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE}  ]]; then
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

  echo "${SSL_CA_CERTIFICATE}" > "${CA_CER}"
  echo "${SSL_PRIVATE_KEY}" > "${SERVER_KEY}"
  echo "${SSL_CERTIFICATE}" > "${SERVER_CER}"
fi

echo '{
  "https": "'"${SERVER_SSL}"'",
  "keyFileName": "'"${SERVER_KEY}"'",
  "keyPassphrase": "",
  "certificateFileName": "'"${SERVER_CER}"'",
  "certificateAuthorityFileName": "'"${CA_CER}"'",
  "gatewayCN": "gateway.user"
}' > security-config.json

exec "$@"
