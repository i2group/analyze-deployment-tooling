#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# Create a Login
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${SA_USERNAME}" -P "${SA_PASSWORD}" -Q "CREATE LOGIN ${DB_USERNAME} WITH PASSWORD = '${DB_PASSWORD}'";

# Create a User
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${SA_USERNAME}" -P "${SA_PASSWORD}" -d "${DB_NAME}" -Q "\
CREATE USER ${DB_USERNAME} FOR LOGIN ${DB_USERNAME} ; \
ALTER ROLE ${DB_ROLE} ADD MEMBER ${DB_USERNAME} ; \
"

echo "Login: $DB_USERNAME User: $DB_USERNAME"

set +e