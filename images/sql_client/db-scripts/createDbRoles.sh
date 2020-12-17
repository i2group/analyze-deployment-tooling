#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# Creating a Role for the DBA_Role
echo "Role: DBA_Role"
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "${DB_NAME}" -Q "
CREATE ROLE DBA_Role;
GRANT CONNECT TO DBA_Role;

GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM TO DBA_Role;
GRANT ALTER, SELECT, UPDATE, INSERT, DELETE, REFERENCES TO DBA_Role;
GRANT EXEC ON SCHEMA::IS_Core TO DBA_Role;
GRANT EXEC ON SCHEMA::IS_Public TO DBA_Role;
"

# Creating a role for populating the external staging tables (External_ETL_Role)
echo "Role: External_ETL_Role"
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "${DB_NAME}" -Q "
CREATE ROLE External_ETL_Role;
GRANT CONNECT TO External_ETL_Role;

GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Staging TO External_ETL_Role;
"

# Creating a role for ETL tasks (i2_ETL_Role)
echo "Role: i2_ETL_Role"
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "${DB_NAME}" -Q "
CREATE ROLE i2_ETL_Role;
GRANT CONNECT TO i2_ETL_Role;

GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM TO i2_ETL_Role;

GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Staging TO i2_ETL_Role;
GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Stg TO i2_ETL_Role;
GRANT SELECT, UPDATE, INSERT ON SCHEMA::IS_Meta TO i2_ETL_Role;
GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Data TO i2_ETL_Role;
GRANT ALTER, SELECT ON SCHEMA::IS_Public TO i2_ETL_Role;
GRANT SELECT, EXEC ON SCHEMA::IS_Core TO i2_ETL_Role;
"

#Creating a Role for the i2Analyze application i2Analyze_Role
echo "Role: i2Analyze_Role"
/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -d "${DB_NAME}" -Q "
CREATE ROLE i2Analyze_Role;
GRANT CONNECT TO i2Analyze_Role;

GRANT CREATE TABLE, CREATE VIEW TO i2Analyze_Role;

GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Staging TO i2Analyze_Role;
GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Stg TO i2Analyze_Role;
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Meta TO i2Analyze_Role;
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Data TO i2Analyze_Role;
GRANT SELECT, UPDATE, INSERT, DELETE, EXEC ON SCHEMA::IS_Core TO i2Analyze_Role;
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_VQ TO i2Analyze_Role;
GRANT SELECT, INSERT, EXEC ON SCHEMA::IS_FP TO i2Analyze_Role;
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_WC TO i2Analyze_Role;
"

set +e