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
function identify_credentials() {
  if [[ -n "${ADMIN_USERNAME}" && -n "${ADMIN_PASSWORD}" ]]; then
    USERNAME="${ADMIN_USERNAME}"
    PASSWORD="${ADMIN_PASSWORD}"
  else
    USERNAME="${DB_USERNAME}"
    PASSWORD="${DB_PASSWORD}"
  fi
}

function run_sql_cmd() {
  local command="${1}"

  ${SQLCMD} "${command}"
}

function attach_to_remote() {
  run_sql_cmd "ATTACH TO \"${DB_NODE}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""
}

function catalog_remote_node() {
  run_sql_cmd "CATALOG TCPIP NODE \"${DB_NODE}\" REMOTE \"${DB_SERVER}\" SERVER \"${DB_PORT}\""
}

function catalog_remote_database() {
  local db_name="${1}"
  run_sql_cmd "CATALOG DATABASE \"${db_name}\" AT NODE \"${DB_NODE}\""
}

function connect_to_database() {
  local db_name="${1}"
  run_sql_cmd "CONNECT TO \"${db_name}\" USER \"${USERNAME}\" USING \"${PASSWORD}\""
}

function connect_to_remote_database() {
  local db_name="${1}"
  identify_credentials

  catalog_remote_node
  catalog_remote_database "${db_name}"
  connect_to_database "${db_name}"
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
#    source /opt/db-scripts/common_functions.sh && run_sql_query 'SELECT 1'
#######################################
function run_sql_query() {
  local sql_query="$1"

  catalog_remote_node
  attach_to_remote

  run_sql_cmd "${sql_query}"

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
#    source /opt/db-scripts/common_functions.sh && run_sql_query_for_db 'SELECT 1' 'master'
#######################################
function run_sql_query_for_db() {
  local sql_query="$1"
  shift
  local sql_db_name="$1"

  connect_to_remote_database "${sql_db_name}"

  run_sql_cmd "${sql_query}"

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
#    source /opt/db-scripts/common_functions.sh && run_sql_file <filepath>
#######################################
function run_sql_file() {
  local file="$1"

  ${SQLCMD} ${SQLCMD_FLAGS} ${file}

  return "${?}"
}
