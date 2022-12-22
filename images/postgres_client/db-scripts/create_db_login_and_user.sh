#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/common_functions.sh'

# Create a user
sql_query="\
    CREATE USER ${DB_USERNAME} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';
        GRANT ${DB_ROLE} TO ${DB_USERNAME}"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

echo "Login: $DB_USERNAME User: $DB_USERNAME"

set +e
