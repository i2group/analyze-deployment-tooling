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

# Creating a Role for the DBA_Role
echo "Role: DBA_Role"
sql_query="\
    CREATE ROLE DBA_Role;
        GRANT CONNECT TO DBA_Role;
            GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM TO DBA_Role;
                GRANT ALTER, SELECT, UPDATE, INSERT, DELETE, REFERENCES TO DBA_Role;
                    GRANT EXEC ON SCHEMA::IS_Core TO DBA_Role;
                        GRANT EXEC ON SCHEMA::IS_Public TO DBA_Role;"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

# Creating a role for populating the external staging tables (External_ETL_Role)
echo "Role: External_ETL_Role"
sql_query="\
    CREATE ROLE External_ETL_Role;
        GRANT CONNECT TO External_ETL_Role;
            GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Staging TO External_ETL_Role;"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

# Creating a role for ETL tasks (i2_ETL_Role)
echo "Role: i2_ETL_Role"
sql_query="\
    CREATE ROLE i2_ETL_Role;
        GRANT CONNECT TO i2_ETL_Role;
            GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM TO i2_ETL_Role;
                GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Staging TO i2_ETL_Role;
                    GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Stg TO i2_ETL_Role;
                        GRANT SELECT, UPDATE, INSERT ON SCHEMA::IS_Meta TO i2_ETL_Role;
                            GRANT ALTER, SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_Data TO i2_ETL_Role;
                                GRANT ALTER, SELECT ON SCHEMA::IS_Public TO i2_ETL_Role;
                                    GRANT SELECT, EXEC ON SCHEMA::IS_Core TO i2_ETL_Role;"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

# Creating a Role for the i2Analyze application i2Analyze_Role
echo "Role: i2Analyze_Role"
sql_query="\
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
                                            GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_WC TO i2Analyze_Role;"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

set +e
