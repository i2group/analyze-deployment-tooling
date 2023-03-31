#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

. /opt/db-scripts/environment.sh
. /opt/db-scripts/common_functions.sh

file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'DB_TRUSTSTORE_PASSWORD'

set -e

if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE" >&2
    exit 1
  fi
  TMP_SECRETS="/tmp/i2acerts"
  CA_CER="${TMP_SECRETS}/CA.cer"
  mkdir "${TMP_SECRETS}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  cp "${CA_CER}" /etc/pki/ca-trust/source/anchors
  update-ca-trust
fi

case "$1" in
"runSQLQuery")
  print_warn "runSQLQuery has been deprecated. Please use run-sql-query instead."
  ;&
  # Fallthrough
"run-sql-query")
  su -p db2inst1 -c "set -e; . /opt/db-scripts/common_functions.sh && run_sql_query \"$2\""
  ;;
"runSQLQueryForDB")
  print_warn "runSQLQueryForDB has been deprecated. Please use run-sql-query-for-db instead."
  ;&
  # Fallthrough
"run-sql-query-for-db")
  su -p db2inst1 -c "set -e; . /opt/db-scripts/common_functions.sh && run_sql_query_for_db \"$2\" \"$3\""
  ;;
"run-sql-file")
  su -p db2inst1 -c "set -e; . /opt/db-scripts/common_functions.sh && run_sql_file \"$2\""
  ;;
*)
  set +e
  su -p db2inst1 -c ". /home/db2inst1/sqllib/db2profile && $(printf '"%s" ' "$@")"
  ;;
esac