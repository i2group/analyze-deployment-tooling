#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

# Disable shellcheck SC2086 as we need word splitting for flags
# shellcheck disable=SC2086
set -e

source '/opt/db-scripts/common_functions.sh'

${SQLCMD} ${SQLCMD_FLAGS} -h "${DB_SERVER}" -p "${DB_PORT}" -d "${DB_NAME}" -f "$1"

set +e
