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

file_env 'SA_PASSWORD'

MSSQL_CONF_FILE="/var/opt/mssql/mssql.conf"

if [[ ${SERVER_SSL} == true ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE"
    exit 1
  fi

  TMP_SECRETS=/tmp/i2acerts
  KEY=${TMP_SECRETS}/server.key
  CER=${TMP_SECRETS}/server.cer

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  if [[ -f ${MSSQL_CONF_FILE} ]]; then
    rm ${MSSQL_CONF_FILE}
  fi

  echo "[network]
tlsprotocols = 1.2
forceencryption = 1
tlscert = ${CER}
tlskey = ${KEY}
" >>${MSSQL_CONF_FILE}
fi

set +e
exec "$@"
