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
