#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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