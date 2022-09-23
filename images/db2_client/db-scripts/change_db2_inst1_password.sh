#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

. /opt/db-scripts/environment.sh
. /opt/db-scripts/common_functions.sh

file_env 'DB2INST1_OLD_PASSWORD'
file_env 'DB2INST1_NEW_PASSWORD'

catalogRemoteNode

# NOTE: This script changes the initial db2inst1 password ("${DB2INST1_OLD_PASSWORD}"),
# and due to this we cannot use the function 'runSQLQuery' in the
# 'common_functions.sh' script to execute the SQL Query, as 'common_functions.sh'
# relies on the password this script sets.
runSQLCMD "ATTACH TO \"${DB_NODE}\" USER \"${DB2INST1_USERNAME}\" USING \"${DB2INST1_OLD_PASSWORD}\" NEW \"${DB2INST1_NEW_PASSWORD}\" CONFIRM \"${DB2INST1_NEW_PASSWORD}\""

set +e
