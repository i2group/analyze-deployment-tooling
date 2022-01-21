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

if [[ ${SERVER_SSL} == true ]]; then
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_PRIVATE_KEY'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE"
    exit 1
  fi

  TMP_SECRETS=/tmp/i2acerts
  CERTIFICATES_FILE="${TMP_SECRETS}/i2Analyze.pem"

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  if [[ -f ${CERTIFICATES_FILE} ]]; then
    rm ${CERTIFICATES_FILE}
  fi
  echo "${SSL_CERTIFICATE}" >>"${CERTIFICATES_FILE}"
  echo "${SSL_PRIVATE_KEY}" >>"${CERTIFICATES_FILE}"
fi

if [[ -f /usr/local/etc/haproxy/haproxy.cfg ]]; then
  rm /usr/local/etc/haproxy/haproxy.cfg
fi

if [[ ${LIBERTY_SSL_CONNECTION} == true ]]; then
  sed "s/SSL_SUB/ssl/" "/usr/local/etc/haproxy/haproxy-template.cfg" >"/usr/local/etc/haproxy/haproxy.cfg"
else
  sed "s/SSL_SUB//" "/usr/local/etc/haproxy/haproxy-template.cfg" >"/usr/local/etc/haproxy/haproxy.cfg"
fi

exec /docker-entrypoint.sh "$@"
