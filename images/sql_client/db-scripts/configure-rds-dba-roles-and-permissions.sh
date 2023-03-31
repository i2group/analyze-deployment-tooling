#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

source '/opt/db-scripts/common_functions.sh'

sql_query="\
    ALTER SERVER ROLE processadmin ADD MEMBER dba;
      GRANT ADMINISTER BULK OPERATIONS TO etl;
        GRANT VIEW SERVER STATE TO dba;"
runSQLQuery "${sql_query}"

sql_query="\
  CREATE USER dba FOR LOGIN dba;
    CREATE USER i2etl FOR LOGIN i2etl;
      EXEC sp_addrolemember [SQLAgentUserRole], [dba];
          GRANT EXECUTE ON msdb.dbo.rds_backup_database TO [dba];
            GRANT EXECUTE ON msdb.dbo.rds_restore_database TO [dba];
              GRANT EXECUTE ON msdb.dbo.rds_task_status TO [dba];
                GRANT EXECUTE ON msdb.dbo.rds_cancel_task TO [dba];
                  GRANT SELECT ON dbo.sysjobs TO [dba];
                      GRANT SELECT ON dbo.sysjobhistory TO [dba];
                        GRANT SELECT ON msdb.dbo.sysjobactivity TO [dba];
                          GRANT EXECUTE ON msdb.dbo.rds_download_from_s3 TO [i2etl]"
runSQLQueryForDB "${sql_query}" "msdb"

set +e
