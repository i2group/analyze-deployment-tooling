#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

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
                                            GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::IS_WC TO i2Analyze_Role;
                                              GRANT EXEC ON SCHEMA::IS_PUBLIC TO i2Analyze_Role;"
runSQLQueryForDB "${sql_query}" "${DB_NAME}"

set +e
