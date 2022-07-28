#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source /opt/db-scripts/commonFunctions.sh

catalogRemoteNode
attachToRemote
catalogRemoteDatabase

sql_query="DROP DATABASE \"${DB_NAME}\""
runSQLCMD "${sql_query}"
