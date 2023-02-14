#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

# Disable shellcheck SC2086 as we need word splitting for flags
# shellcheck disable=SC2086
set -e

. /opt/db-scripts/environment.sh

file_env 'POSTGRES_OLD_PASSWORD'
file_env 'POSTGRES_NEW_PASSWORD'

export PGPASSWORD="${POSTGRES_OLD_PASSWORD}"

# NOTE: This script changes the initial password ("${POSTGRES_OLD_PASSWORD}"),
# and due to this we cannot use the function 'run-sql-query' in the
# 'common_functions.sh' script to execute the SQL Query, as 'common_functions.sh'
# relies on the password this script sets.
"${SQLCMD}" ${SQLCMD_FLAGS} -h "${DB_SERVER}" -p "${DB_PORT}" -c "ALTER ROLE \"${PGUSER}\" WITH PASSWORD '${POSTGRES_NEW_PASSWORD}'"

set +e
