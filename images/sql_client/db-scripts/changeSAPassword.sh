#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

. /opt/db-scripts/environment.sh

file_env 'SA_OLD_PASSWORD'
file_env 'SA_NEW_PASSWORD'

# NOTE: This script changes the initial SQL password ("${SA_OLD_PASSWORD}"),
# and due to this we cannot use the function 'runSQLQuery' in the
# 'commonFunctions.sh' script to execute the SQL Query, as 'commonFunctions.sh'
# relies on the password this script sets.
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${SA_USERNAME}" -P "${SA_OLD_PASSWORD}" -Q "ALTER LOGIN ${SA_USERNAME} WITH PASSWORD=\"${SA_NEW_PASSWORD}\""

set +e
