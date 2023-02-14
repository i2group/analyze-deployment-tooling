#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

# Disable shellcheck SC2086 as we need word splitting for flags
# shellcheck disable=SC2086

#######################################
# Prints an error message to the console
# Arguments:
#   1: The message
#######################################
function print_warn() {
  printf "\n\e[33mWARN: %s\n" "$1" >&2
  printf "\e[0m" >&2
}

#######################################
# Perform a custom SQL Query from the Postgres Client container to the
# Postgres Server container.
#
# Arguments:
#   (1) SQL Query to perform e.g. 'SELECT 1'
# Output:
#   Return code for SQL Query
# Example:
#    source /opt/db-scripts/common_functions.sh && run_sql_query 'SELECT 1'
#######################################
function run_sql_query() {
  local sql_query="$1"

  "${SQLCMD}" ${SQLCMD_FLAGS} -h "${DB_SERVER}" -p "${DB_PORT}" -c "${sql_query}"

  return "${?}"
}

#######################################
# Perform a custom SQL Query from the Postgres Client container to the
# Postgres Server container for a specific database.
#
# Arguments:
#   (1) SQL Query to perform e.g. 'SELECT 1'
#   (2) SQL Database name to perform query on e.g. 'master'
# Output:
#   Return code for SQL Query
# Example:
#    source /opt/db-scripts/common_functions.sh && run_sql_query_for_db 'SELECT 1' 'master'
#######################################
function run_sql_query_for_db() {
  local sql_query="$1"
  shift
  local sql_db_name="$1"

  "${SQLCMD}" ${SQLCMD_FLAGS} -h "${DB_SERVER}" -p "${DB_PORT}" -d "${sql_db_name}" -c "${sql_query}"

  return "${?}"
}
