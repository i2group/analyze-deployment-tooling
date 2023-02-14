#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/common_functions.sh'

# Add user to role
sql_query="\
    ALTER ROLE ${DB_ROLE} ADD MEMBER ${DB_USERNAME}"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

set +e
