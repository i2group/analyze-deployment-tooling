#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

. /opt/db-scripts/environment.sh

file_env 'SA_USERNAME'
file_env 'SA_PASSWORD'
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'DB_TRUSTSTORE_PASSWORD'

set -e

if [[ ${DB_SSL_CONNECTION} == true ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
    exit 1
  fi
  TMP_SECRETS=/tmp/i2acerts
  CA_CER=${TMP_SECRETS}/CA.cer
  mkdir ${TMP_SECRETS}
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  cp "${CA_CER}" /etc/pki/ca-trust/source/anchors
  update-ca-trust
  for file in /opt/*.sh; do
    sed -i 's/sqlcmd/sqlcmd -N/g' "$file"
  done
fi

set +e
exec "$@"
