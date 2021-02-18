#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# Add dba user to required roles in msdb
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "msdb" -Q "
CREATE USER dba FOR LOGIN dba;
ALTER ROLE SQLAgentUserRole ADD MEMBER dba;
ALTER ROLE db_datareader ADD MEMBER dba;"

# Grant dba required permission to be able execute scheduled jobs as the first step of a deletion by rule job checks the server's HADR state.
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "master" -Q "
CREATE USER dba FOR LOGIN dba;
GRANT CONNECT TO dba;
GRANT VIEW SERVER STATE TO dba;
GRANT EXECUTE ON sys.fn_hadr_is_primary_replica TO dba;
"

set +e