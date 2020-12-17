#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# Grant a user sysAdmin (add this user to the members of sysadmin)
# This is only intended for the etl user which requires BULK INSERT permission, granting sysadmin is necessary in this case as the SQL Server is running on Linux
# See: https://docs.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql?view=sql-server-2017#permissions
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -Q "ALTER SERVER ROLE sysadmin ADD MEMBER etl";

set +e