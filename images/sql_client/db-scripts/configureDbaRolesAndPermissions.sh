#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/commonFunctions.sh'

# Add dba user to required roles in msdb
sql_query="\
    CREATE USER dba FOR LOGIN dba;
        ALTER ROLE SQLAgentUserRole ADD MEMBER dba;
            ALTER ROLE db_datareader ADD MEMBER dba;"
runSQLQueryForDB "${sql_query}" "msdb"

# Grant dba required permission to be able execute scheduled jobs as the first step of a deletion by rule job checks the server's HADR state.
sql_query="\
    CREATE USER dba FOR LOGIN dba;
        GRANT CONNECT TO dba;
            GRANT VIEW SERVER STATE TO dba;
                GRANT EXECUTE ON sys.fn_hadr_is_primary_replica TO dba;"
runSQLQueryForDB "${sql_query}" "master"

set +e
