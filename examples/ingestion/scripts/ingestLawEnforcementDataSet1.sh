#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
set -e

# cspell:ignore organisation acessto

###############################################################################
# Etl variables                                                               #
###############################################################################
BASE_DATA="law-enforcement-data-set-1"
STAGING_SCHEMA="IS_STAGING"
IMPORT_MAPPING_FILE="/var/i2a-data/${BASE_DATA}/mapping.xml"

###############################################################################
# Constants                                                                   #
###############################################################################
# Array for base data tables to csv and format file names
BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME=base_data_table_to_csv_and_format_file_name_map_
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Account" "account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Address" "address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Communications_D" "telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Event" "event"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Organization" "organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Person" "person"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Property" "property"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Vehicle" "vehicle"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Org_Acc" "organisation_accessto_account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Org_Add" "organisation_accessto_address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Per_Acc" "person_accessto_account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Per_Add" "person_accessto_address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Org_Own_Veh" "organisation_accessto_vehicle"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Per_Own_Tel" "person_owner_accessto_telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Per_Own_Veh" "person_owner_acessto_vehicle"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Per_Sh_Org" "person_shareholder_accessto_organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Associate" "person_association_person"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Communication" "telephone_calls_telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Employment" "person_employedby_organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Involved_In_Eve_Per" "event_involvedin_person"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Transaction" "account_transaction_account"

# Import IDs used for ingestion with BULK import mode
BULK_IMPORT_MAPPING_IDS=(
  "Account" "Address" "Telephone" "Event" "Organisation" "Person" "Property" "Vehicle" "AccessToOrgAcc" "AccessToOrgAdd" "AccessToPerAcc" "AccessToPerAdd" "AccessToOrgOwnVeh" "AccessToPerOwnTel" "AccessToPerOwnVeh" "AccessToPerShOrg" "Associate" "Communication" "Employment" "InvolvedInEvePer" "Transaction"
)

###############################################################################
# Ingesting base data                                                         #
###############################################################################
print "Inserting data into the staging tables"
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
# Any double quotes in the curl command are also escaped by a leading backslash.
for table_name in $(map_keys "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}" "${table_name}")
  case "${DB_DIALECT}" in
  db2)
    IFS=',' read -r -a csv_header <"${DATA_DIR}/${BASE_DATA}/${csv_and_format_file_name}.csv"
    columns=()
    for header in "${csv_header[@]}"; do
      columns+=("${header} varchar(1000) NULL")
    done
    sql_query="\
        INSERT INTO ${STAGING_SCHEMA}.${table_name} ($(
      IFS=','
      echo "${csv_header[*]}"
    )) \
        SELECT * FROM EXTERNAL '/var/i2a-data/${BASE_DATA}/${csv_and_format_file_name}.csv' ($(
      IFS=','
      echo "${columns[*]}"
    )) \
        USING (DELIMITER ',' SKIP_ROWS 1 TIMESTAMP_FORMAT 'YYYY-MM-DD HH:MI:SS' DATE_FORMAT 'YYYY-MM-DD' NULLVALUE '')"
    runDb2ServerCommandAsDb2inst1 runSQLQueryForDB "${sql_query}" "${DB_NAME}"
    ;;
  sqlserver)
    sql_query="\
        BULK INSERT ${STAGING_SCHEMA}.${table_name} \
        FROM '/var/i2a-data/${BASE_DATA}/${csv_and_format_file_name}.csv' \
        WITH (FORMATFILE = '/var/i2a-data/${BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)"
    runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
    ;;
  esac
done

for import_id in "${BULK_IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode BULK"
done

###############################################################################
# Truncating the staging tables                                               #
###############################################################################
print "Truncating the staging tables"
for table_name in $(map_keys "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}" "${table_name}")
  sql_query="TRUNCATE TABLE ${STAGING_SCHEMA}.${table_name}"
  case "${DB_DIALECT}" in
  db2)
    sql_query+=" IMMEDIATE;"
    runDb2ServerCommandAsDb2inst1 runSQLQueryForDB "${sql_query}" "${DB_NAME}"
    ;;
  sqlserver)
    runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
    ;;
  esac
done
