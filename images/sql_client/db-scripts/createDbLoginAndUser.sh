#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/commonFunctions.sh'

# Create a Login
sql_query="\
    CREATE LOGIN ${DB_USERNAME} WITH PASSWORD = '${DB_PASSWORD}'"
runSQLQuery "${sql_query}"

# Create a User
sql_query="\
    CREATE USER ${DB_USERNAME} FOR LOGIN ${DB_USERNAME};
        ALTER ROLE ${DB_ROLE} ADD MEMBER ${DB_USERNAME}"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

echo "Login: $DB_USERNAME User: $DB_USERNAME"

set +e
