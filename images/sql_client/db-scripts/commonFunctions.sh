#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

# Disable shellcheck SC2086 as we need word splitting for flags
# shellcheck disable=SC2086

#######################################
# Identify correct credentials from env var's defined for SQL
# Client container.
#
# Arguments:
#   N/A
# Output:
#   N/A
# Example:
#   N/A
#######################################
function identifyCredentials() {
  if [[ -n "${SA_USERNAME}" && -n "${SA_PASSWORD}" ]]; then
    USERNAME="${SA_USERNAME}"
    PASSWORD="${SA_PASSWORD}"
  else
    USERNAME="${DB_USERNAME}"
    PASSWORD="${DB_PASSWORD}"
  fi
}

#######################################
# Perform a custom SQL Query from the SQL Client container to the
# SQL Server container.
#
# Arguments:
#   (1) SQL Query to perform e.g. 'SELECT 1'
# Output:
#   Return code for SQL Query
# Example:
#    source /opt/db-scripts/commonFunctions.sh && runSQLQuery 'SELECT 1'
#######################################
function runSQLQuery() {
  local sql_query="$1"

  identifyCredentials

  ${SQLCMD} ${SQLCMD_FLAGS} -C -S "${DB_SERVER}","${DB_PORT}" \
    -U "${USERNAME}" -P "${PASSWORD}" -Q "${sql_query}"

  return "${?}"
}

#######################################
# Perform a custom SQL Query from the SQL Client container to the
# SQL Server container for a specific database.
#
# Arguments:
#   (1) SQL Query to perform e.g. 'SELECT 1'
#   (2) SQL Database name to perform query on e.g. 'master'
# Output:
#   Return code for SQL Query
# Example:
#    source /opt/db-scripts/commonFunctions.sh && runSQLQueryForDB 'SELECT 1' 'master'
#######################################
function runSQLQueryForDB() {
  local sql_query="$1"
  shift
  local sql_db_name="$1"

  identifyCredentials

  ${SQLCMD} ${SQLCMD_FLAGS} -C -S "${DB_SERVER}","${DB_PORT}" \
    -U "${USERNAME}" -P "${PASSWORD}" -d "${sql_db_name}" -Q "${sql_query}"

  return "${?}"
}
