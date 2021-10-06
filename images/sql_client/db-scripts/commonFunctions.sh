#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2021, IBM Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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