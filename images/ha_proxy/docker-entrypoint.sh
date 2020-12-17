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
