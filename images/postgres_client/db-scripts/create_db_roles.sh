#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/common_functions.sh'

# Creating a Role for the DBA_Role
echo "Role: DBA_Role"
sql_query="\
    CREATE ROLE DBA_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO DBA_Role;
            GRANT CREATE ON DATABASE \"${DB_NAME}\" TO DBA_Role;
                ALTER SCHEMA IS_Staging OWNER TO DBA_Role;
                    ALTER SCHEMA IS_Stg OWNER TO DBA_Role;
                        ALTER SCHEMA IS_Meta OWNER TO DBA_Role;
                            ALTER SCHEMA IS_Data OWNER TO DBA_Role;
                                ALTER SCHEMA IS_Core OWNER TO DBA_Role;
                                    ALTER SCHEMA IS_VQ OWNER TO DBA_Role;
                                        ALTER SCHEMA IS_FP OWNER TO DBA_Role;
                                            ALTER SCHEMA IS_WC OWNER TO DBA_Role;
                                                ALTER SCHEMA IS_Public OWNER TO DBA_Role;
    CREATE EXTENSION pg_cron;
        GRANT USAGE ON SCHEMA cron TO DBA_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

# Creating other roles
sql_query="\
    CREATE ROLE External_ETL_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO External_ETL_Role;
            GRANT pg_read_server_files TO External_ETL_Role;
    CREATE ROLE i2_ETL_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO i2_ETL_Role;
            GRANT CREATE ON DATABASE \"${DB_NAME}\" TO i2_ETL_Role;
    CREATE ROLE i2Analyze_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO i2Analyze_Role;
    CREATE ROLE DBB_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO DBB_Role;
    CREATE ROLE i2_Public_Role;
        GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO i2_Public_Role;"
run_sql_query_for_db "${sql_query}" "${DB_NAME}"

set +e
