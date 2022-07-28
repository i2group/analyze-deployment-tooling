#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

###############################################################################
# Etl variables                                                               #
###############################################################################
STAGING_SCHEMA="IS_STAGING"

###############################################################################
# Constants                                                                   #
###############################################################################
# Array for schema type ID to table name
SCHEMA_TYPE_ID_TO_TABLE_NAME=schema_type_id_to_table_name_map_
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET1" "E_Address"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET2" "E_Event"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET3" "E_Vehicle"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET4" "E_Organization"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET5" "E_Person"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET9" "E_Property"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET10" "E_Account"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LAC1" "L_To_Per_Own_Veh L_Access_To_Org_Add L_Access_To_Per_Acc L_Access_To_Per_Add L_To_Per_Own_Tel L_To_Org_Own_Veh L_Access_To_Org_Acc L_To_Per_Sh_Org"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LAS1" "L_Associate"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LCO1" "L_Communication"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LIN1" "L_Involved_In_Eve_Per"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LEM1" "L_Employment"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LTR1" "L_Transaction"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET8" "E_Communications_D"

###############################################################################
# Deleting the staging tables                                                 #
###############################################################################
print "Deleting the staging tables"
for schema_type_id in $(map_keys "$SCHEMA_TYPE_ID_TO_TABLE_NAME"); do
  for table_name in $(map_get "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "$schema_type_id"); do
    sql_query="DROP TABLE ${STAGING_SCHEMA}.${table_name}"
    case "${DB_DIALECT}" in
    db2)
      runDb2ServerCommandAsDb2inst1 runSQLQueryForDB "${sql_query}" "${DB_NAME}"
      ;;
    sqlserver)
      runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
      ;;
    esac
  done
done
