#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

source /opt/db-scripts/common_functions.sh

catalog_remote_node
attach_to_remote
catalog_remote_database

sql_query="DROP DATABASE \"${DB_NAME}\""
run_sql_cmd "${sql_query}"
