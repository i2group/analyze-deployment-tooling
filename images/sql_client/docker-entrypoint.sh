#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

. /opt/db-scripts/environment.sh
. /opt/db-scripts/common_functions.sh

file_env 'SA_USERNAME'
file_env 'SA_PASSWORD'
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'DB_TRUSTSTORE_PASSWORD'

set -e

TMP_SECRETS="/tmp/i2acerts"

if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE" >&2
    exit 1
  fi
  CA_CER="${TMP_SECRETS}/CA.cer"

  # Create a directory if it doesn't exist
  if [[ ! -d "${TMP_SECRETS}" ]]; then
    mkdir -p "${TMP_SECRETS}"
  fi
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  cp "${CA_CER}" /etc/pki/ca-trust/source/anchors
  update-ca-trust
  for file in /opt/*.sh; do
    sed -i 's/sqlcmd/sqlcmd -N/g' "$file"
  done
fi

function run_with_user() {
  exec /usr/local/bin/gosu "${USER}" "$@"
}

# If user not root ensure to give correct permissions before start
if [ -n "$GROUP_ID" ] && [ "$GROUP_ID" != "0" ]; then
  if [ "$(getent group "${USER}")" ]; then
    groupmod -g "$GROUP_ID" "${USER}" &>/dev/null
  else
    groupadd -g "$GROUP_ID" "${USER}" &>/dev/null
  fi
  usermod -u "$USER_ID" -g "$GROUP_ID" "${USER}" &>/dev/null
  chown -R "${USER_ID}:0" "/opt/databaseScripts/generated" \
    "/opt/customDatabaseScripts" \
    "/opt/toolkit" \
    "/etc/pki" \
    "${TMP_SECRETS}"
fi

case "$1" in
"runSQLQuery")
  printWarn "runSQLQuery has been deprecated. Please use run-sql-query instead."
  ;&
  # Fallthrough
"run-sql-query")
  run_with_user /opt/db-scripts/run_sql_query.sh "$2"
  ;;
"runSQLQueryForDB")
  printWarn "runSQLQueryForDB has been deprecated. Please use run-sql-query-for-db instead."
  ;&
  # Fallthrough
"run-sql-query-for-db")
  run_with_user /opt/db-scripts/run_sql_query.sh "$2" "$3"
  ;;
"run-sql-file")
  run_with_user /opt/db-scripts/run_sql_file.sh "$2"
  ;;
*)
  set +e
  run_with_user "$@"
  ;;
esac
