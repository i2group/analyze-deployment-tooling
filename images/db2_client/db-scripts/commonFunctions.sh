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

function runSQLCMD() {
  local command="${1}"

  ${SQLCMD} "${command}"
}

function attachToRemote() {
  runSQLCMD "ATTACH TO \"${DB_NODE}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""
}

function catalogRemoteNode() {
  runSQLCMD "CATALOG TCPIP NODE \"${DB_NODE}\" REMOTE \"${DB_SERVER}\" SERVER \"${DB_PORT}\""
}

function catalogRemoteDatabase() {
  local db_name="${1}"
  runSQLCMD "CATALOG DATABASE \"${db_name}\" AT NODE \"${DB_NODE}\""
}

function connectToDatabase() {
  local db_name="${1}"
  runSQLCMD "CONNECT TO \"${db_name}\" USER \"${USERNAME}\" USING \"${PASSWORD}\""
}

function connectToRemoteDatabase() {
  local db_name="${1}"
  identifyCredentials

  catalogRemoteNode
  catalogRemoteDatabase "${db_name}"
  connectToDatabase "${db_name}"
}

#######################################
# Perform a custom SQL Query from the Db2 Client container to the
#  Db2 Server container.
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

  catalogRemoteNode
  attachToRemote

  runSQLCMD "${sql_query}"

  return "${?}"
}

#######################################
# Perform a custom SQL Query from the Db2 Client container to the
#  Db2 Server container for a specific database.
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

  connectToRemoteDatabase "${sql_db_name}"

  runSQLCMD "${sql_query}"

  return "${?}"
}

#######################################
# Execute a custom file from the Db2 Client container to the
#  Db2 Server container.
#
# Arguments:
#   (1) Filepath
# Output:
#   Return code for SQL Query
# Example:
#    source /opt/db-scripts/commonFunctions.sh && runSQLFile <filepath>
#######################################
function runSQLFile() {
  local file="$1"

  ${SQLCMD} ${SQLCMD_FLAGS} ${file}

  return "${?}"
}
