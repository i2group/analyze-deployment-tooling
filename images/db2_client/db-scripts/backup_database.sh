#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

. /opt/db-scripts/environment.sh
. /opt/db-scripts/common_functions.sh

connect_to_remote_database "${DB_NAME}"
run_sql_cmd "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS"
run_sql_cmd "CONNECT RESET"

sql_query="BACKUP DATABASE \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\" TO \"$1\" EXCLUDE LOGS WITHOUT PROMPTING"
max_retries=10

while [ $max_retries -gt 0 ]; do
  if run_sql_cmd "${sql_query}"; then
    break;
  else
    ((max_retries--))
    sleep 30
  fi
done

if [[ $max_retries -eq 0 ]]; then
  echo "Cannot perform backup"
  exit 1
fi

connect_to_database "${DB_NAME}"
run_sql_cmd "UNQUIESCE DATABASE"
