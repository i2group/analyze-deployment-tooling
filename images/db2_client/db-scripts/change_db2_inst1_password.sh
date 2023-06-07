#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

. /opt/db-scripts/environment.sh
. /opt/db-scripts/common_functions.sh

file_env 'DB2INST1_OLD_PASSWORD'
file_env 'DB2INST1_NEW_PASSWORD'

catalog_remote_node

attach_query="ATTACH TO \"${DB_NODE}\" USER \"${DB2INST1_USERNAME}\" USING \"${DB2INST1_OLD_PASSWORD}\" NEW \"${DB2INST1_NEW_PASSWORD}\" CONFIRM \"${DB2INST1_NEW_PASSWORD}\""
max_retries=10

# NOTE: This script changes the initial db2inst1 password ("${DB2INST1_OLD_PASSWORD}"),
# and due to this we cannot use the function 'run_sql_query' in the
# 'common_functions.sh' script to execute the SQL Query, as 'common_functions.sh'
# relies on the password this script sets.
while [ $max_retries -gt 0 ]; do
  if run_sql_cmd "${attach_query}"; then
    echo "DB2 password has been changed successfully."
    break
  else
    ((max_retries--))
    echo "The command to change DB2 password was not successful (attempt: ${max_retries}). Waiting..."
    sleep 5
  fi
done

if [[ $max_retries -eq 0 ]]; then
  echo "Cannot change DB2 password."
  exit 1
fi

set +e
