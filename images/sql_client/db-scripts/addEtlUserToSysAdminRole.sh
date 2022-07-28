#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/commonFunctions.sh'

# Grant a user sysAdmin (add this user to the members of sysadmin)
# This is only intended for the etl user which requires BULK INSERT permission, granting sysadmin is necessary in this case as the SQL Server is running on Linux
# See: https://docs.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql?view=sql-server-2017#permissions
sql_query="\
    ALTER SERVER ROLE sysadmin ADD MEMBER etl"
runSQLQuery "${sql_query}"

set +e
