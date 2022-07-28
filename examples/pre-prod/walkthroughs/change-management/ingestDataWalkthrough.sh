#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "This project should be run inside a VSCode Dev Container. For more information read, the Getting Started guide at https://i2group.github.io/analyze-containers/content/getting_started.html"
  exit 1
fi

# cspell:ignore organisation acessto

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

warnRootDirNotInPath
setDependenciesTagIfNecessary
###############################################################################
# Etl variables                                                               #
###############################################################################
BASE_DATA="law-enforcement-data-set-1"
CORRELATION_BASE_DATA="law-enforcement-data-set-2"
CORRELATION_MERGE_DATA="law-enforcement-data-set-2-merge"
INGESTION_SOURCE_DESCRIPTION="cloud example"
INGESTION_SOURCE_NAME_1="EXAMPLE_1"
INGESTION_SOURCE_NAME_2="EXAMPLE_2"
STAGING_SCHEMA="IS_STAGING"
IMPORT_MAPPING_FILE="/var/i2a-data/law-enforcement-data-set-1/mapping.xml"

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

# Array for base data tables to csv and format file names
BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME=base_data_table_to_csv_and_format_file_name_map_
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Event" "event"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Address" "address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Organization" "organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Communications_D" "telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Account" "account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Property" "property"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Per_Acc" "person_accessto_account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Per_Add" "person_accessto_address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Org_Add" "organisation_accessto_address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Org_Acc" "organisation_accessto_account"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Org_Own_Veh" "organisation_accessto_vehicle"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Per_Own_Tel" "person_owner_accessto_telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Communication" "telephone_calls_telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Involved_In_Eve_Per" "event_involvedin_person"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_To_Per_Sh_Org" "person_shareholder_accessto_organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Employment" "person_employedby_organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Associate" "person_association_person"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Transaction" "account_transaction_account"

# Array for correlated data tables to csv and format file names
CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME=correlated_data_table_and_format_file_name_map_
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "E_Person" "person"
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "E_Vehicle" "vehicle"
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "L_To_Per_Own_Veh" "person_owner_acessto_vehicle"

# Import IDs used for ingestion with STANDARD import mode
IMPORT_MAPPING_IDS=("Person" "Vehicle" "Property" "AccessToPerOwnVeh" "Account" "AccessToPerAcc" "AccessToPerAdd" "AccessToPerOwnTel" "AccessToOrgOwnVeh" "AccessToOrgAcc" "InvolvedInEvePer" "AccessToPerShOrg" "Employment" "Associate" "Transaction")

# Import IDs used for ingestion with BULK import mode
BULK_IMPORT_MAPPING_IDS=("Event" "Address" "Organisation" "telephone" "Communication" "AccessToOrgAdd")

###############################################################################
# Creating the ingestion sources                                              #
###############################################################################
print "Adding Information Store Ingestion Source(s)"
runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/addInformationStoreIngestionSource \
--ingestionSourceDescription ${INGESTION_SOURCE_DESCRIPTION} \
--ingestionSourceName ${INGESTION_SOURCE_NAME_1}"

runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/addInformationStoreIngestionSource \
--ingestionSourceDescription ${INGESTION_SOURCE_DESCRIPTION} \
--ingestionSourceName ${INGESTION_SOURCE_NAME_2}"

###############################################################################
# Creating the staging tables                                                 #
###############################################################################
print "Creating Information Store Staging Table(s)"
for schema_type_id in $(map_keys "${SCHEMA_TYPE_ID_TO_TABLE_NAME}"); do
  for table_name in $(map_get "${SCHEMA_TYPE_ID_TO_TABLE_NAME}" "${schema_type_id}"); do
    runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/createInformationStoreStagingTable \
      --schemaTypeId ${schema_type_id} \
      --tableName ${table_name}  \
      --databaseSchemaName ${STAGING_SCHEMA}"
  done
done

###############################################################################
# Ingesting base data                                                         #
###############################################################################
print "Inserting data into the staging tables"
# To stop the variables being evaluated in this script, the variables are escaped using backslashes (\) and surrounded in double quotes (").
# Any double quotes in the curl command are also escaped by a leading backslash.
for table_name in $(map_keys "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME}" "${table_name}")
  sql_query="\
    BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/var/i2a-data/${BASE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/var/i2a-data/${BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)"
  runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
done

for import_id in "${BULK_IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode BULK"
done

###############################################################################
# Ingesting correlation data                                                  #
###############################################################################
print "Inserting correlation data into the staging tables"
for table_name in $(map_keys "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}" "${table_name}")
  sql_query="\
    BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/var/i2a-data/${CORRELATION_BASE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/var/i2a-data/${CORRELATION_BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)"
  runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
done

print "Ingesting the CORRELATED data"
for import_id in "${IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode STANDARD"
done

print "Cleaning the staging tables"
for table_name in $(map_keys "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}" "${table_name}")
  sql_query="\
    TRUNCATE Table ${STAGING_SCHEMA}.${table_name}"
  runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
done

###############################################################################
# Ingesting merge correlation data                                            #
###############################################################################

# Copy the merge person.csv
cp "${LOCAL_CONFIG_CHANGES_DIR}/person.csv" "${LOCAL_TOOLKIT_DIR}/examples/data/${CORRELATION_MERGE_DATA}/"

print "Inserting merge correlation data into into the staging tables"
for table_name in $(map_keys "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}"); do
  csv_and_format_file_name=$(map_get "${CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME}" "${table_name}")
  sql_query="\
    BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/var/i2a-data/${CORRELATION_MERGE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/var/i2a-data/${CORRELATION_MERGE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)"
  runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
done

print "Ingesting the merge correlation data"
for import_id in "${IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/i2/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode STANDARD"
done

###############################################################################
# Deleting the staging tables                                                 #
###############################################################################
print "Deleting the staging tables"
for schema_type_id in $(map_keys "$SCHEMA_TYPE_ID_TO_TABLE_NAME"); do
  for table_name in $(map_get "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "$schema_type_id"); do
    sql_query="\
      DROP TABLE ${STAGING_SCHEMA}.${table_name}"
    runSQLServerCommandAsETL runSQLQueryForDB "${sql_query}" "${DB_NAME}"
  done
done

set +e
