#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/common_functions.sh'

# Creating a role for populating the external staging tables (External_ETL_Role)
echo "Role: External_ETL_Role"
sql_query="\
    GRANT USAGE ON SCHEMA IS_Staging TO External_ETL_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Staging GRANT ALL ON TABLES TO External_ETL_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

# Creating a role for ETL tasks (i2_ETL_Role)
echo "Role: i2_ETL_Role"
sql_query="\
    GRANT USAGE, CREATE ON SCHEMA IS_Staging TO i2_ETL_Role;
        GRANT USAGE, CREATE ON SCHEMA IS_Stg TO i2_ETL_Role;
            GRANT USAGE ON SCHEMA IS_Meta TO i2_ETL_Role;
                GRANT USAGE ON SCHEMA IS_Data TO i2_ETL_Role;
                    GRANT USAGE ON SCHEMA IS_Public TO i2_ETL_Role;
                        GRANT USAGE ON SCHEMA IS_Core TO i2_ETL_Role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Staging GRANT ALL ON TABLES TO i2_ETL_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Stg GRANT ALL ON TABLES TO i2_ETL_Role;
            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Meta GRANT SELECT, UPDATE, INSERT ON TABLES TO i2_ETL_Role;
                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Data GRANT SELECT, UPDATE, INSERT, DELETE ON TABLES TO i2_ETL_Role;
                    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Public GRANT SELECT ON TABLES TO i2_ETL_Role;
                        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT SELECT ON TABLES TO i2_ETL_Role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT EXECUTE ON ROUTINES TO i2_ETL_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Data GRANT USAGE, SELECT ON SEQUENCES TO i2_ETL_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

# Creating a Role for the i2 Analyze application i2Analyze_Role
echo "Role: i2Analyze_Role"
sql_query="\
    GRANT USAGE, CREATE ON SCHEMA IS_Staging TO i2Analyze_Role;
        GRANT USAGE, CREATE ON SCHEMA IS_Stg TO i2Analyze_Role;
            GRANT USAGE ON SCHEMA IS_Meta TO i2Analyze_Role;
                GRANT USAGE ON SCHEMA IS_Data TO i2Analyze_Role;
                    GRANT USAGE ON SCHEMA IS_Core TO i2Analyze_Role;
                        GRANT USAGE ON SCHEMA IS_VQ TO i2Analyze_Role;
                            GRANT USAGE ON SCHEMA IS_FP TO i2Analyze_Role;
                                GRANT USAGE ON SCHEMA IS_WC TO i2Analyze_Role;
                                    GRANT USAGE ON SCHEMA IS_PUBLIC TO i2Analyze_Role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Staging GRANT ALL ON TABLES TO i2Analyze_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Stg GRANT ALL ON TABLES TO i2Analyze_Role;
            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Meta GRANT ALL ON TABLES TO i2Analyze_Role;
                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Data GRANT ALL ON TABLES TO i2Analyze_Role;
                    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT ALL ON TABLES TO i2Analyze_Role;
                        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_VQ GRANT ALL ON TABLES TO i2Analyze_Role;
                            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_FP GRANT SELECT, INSERT ON TABLES TO i2Analyze_Role;
                                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_WC GRANT ALL ON TABLES TO i2Analyze_Role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT EXECUTE ON ROUTINES TO i2Analyze_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_FP GRANT EXECUTE ON ROUTINES TO i2Analyze_Role;
            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_PUBLIC GRANT EXECUTE ON ROUTINES TO i2Analyze_Role;
                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Data GRANT USAGE, SELECT ON SEQUENCES TO i2Analyze_Role;
                    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_WC GRANT USAGE, SELECT ON SEQUENCES TO i2Analyze_Role;
                        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT USAGE, SELECT ON SEQUENCES TO i2Analyze_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

# Creating a Role for the DBB_Role
echo "Role: DBB_Role"
sql_query="\
    GRANT USAGE ON SCHEMA IS_Staging TO DBB_Role;
        GRANT USAGE ON SCHEMA IS_Stg TO DBB_Role;
            GRANT USAGE ON SCHEMA IS_Meta TO DBB_Role;
                GRANT USAGE ON SCHEMA IS_Data TO DBB_Role;
                    GRANT USAGE ON SCHEMA IS_Core TO DBB_Role;
                        GRANT USAGE ON SCHEMA IS_VQ TO DBB_Role;
                            GRANT USAGE ON SCHEMA IS_FP TO DBB_Role;
                                GRANT USAGE ON SCHEMA IS_WC TO DBB_Role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Staging GRANT SELECT ON TABLES TO DBB_Role;
        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Stg GRANT SELECT ON TABLES TO DBB_Role;
            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Meta GRANT SELECT ON TABLES TO DBB_Role;
                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Data GRANT SELECT ON TABLES TO DBB_Role;
                    ALTER DEFAULT PRIVILEGES IN SCHEMA IS_Core GRANT SELECT ON TABLES TO DBB_Role;
                        ALTER DEFAULT PRIVILEGES IN SCHEMA IS_VQ GRANT SELECT ON TABLES TO DBB_Role;
                            ALTER DEFAULT PRIVILEGES IN SCHEMA IS_FP GRANT SELECT ON TABLES TO DBB_Role;
                                ALTER DEFAULT PRIVILEGES IN SCHEMA IS_WC GRANT SELECT ON TABLES TO DBB_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

set +e
