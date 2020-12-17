#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

# This is to ensure the script can be run from any directory
SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"

# Set the root directory
ROOT_DIR=$(pwd)/../../../..

# Load common variables and functions
source ../../utils/commonVariables.sh
source ../../utils/commonFunctions.sh
source ../../utils/serverFunctions.sh
source ../../utils/clientFunctions.sh

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
IMPORT_MAPPING_FILE="/tmp/examples/data/law-enforcement-data-set-1/mapping.xml"

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
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LAC1" "L_To_Per_Own_Veh L_Access_To_Org_Add"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "LCO1" "L_Communication"
map_put "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "ET8" "E_Communications_D"

# Array for base data tables to csv and format file names
BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME=base_data_table_to_csv_and_format_file_name_map_
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Event" "event"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Address" "address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Organization" "organisation"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "E_Communications_D" "telephone"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Access_To_Org_Add" "organisation_accessto_address"
map_put "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "L_Communication" "telephone_calls_telephone"

# Array for correlated data tables to csv and format file names
CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME=correlated_data_table_and_format_file_name_map_
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "E_Person" "person"
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "E_Vehicle" "vehicle"
map_put "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "L_To_Per_Own_Veh" "person_owner_acessto_vehicle"

# Import IDs used for ingestion with STANDARD import mode
IMPORT_MAPPING_IDS=("Person" "Vehicle" "AccessToPerOwnVeh")

# Import IDs used for ingestion with BULK import mode
BULK_IMPORT_MAPPING_IDS=("Event" "Address" "Organisation" "telephone" "Communication" "AccessToOrgAdd")

###############################################################################
# Creating the ingestion sources                                              #
###############################################################################
print "Adding Information Store Ingestion Source(s)"
runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/addInformationStoreIngestionSource \
--ingestionSourceDescription ${INGESTION_SOURCE_DESCRIPTION} \
--ingestionSourceName ${INGESTION_SOURCE_NAME_1}"

runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/addInformationStoreIngestionSource \
--ingestionSourceDescription ${INGESTION_SOURCE_DESCRIPTION} \
--ingestionSourceName ${INGESTION_SOURCE_NAME_2}"

###############################################################################
# Creating the staging tables                                                 #
###############################################################################
print "Creating Information Store Staging Table(s)"
for schema_type_id in $(map_keys "$SCHEMA_TYPE_ID_TO_TABLE_NAME"); do
  for table_name in $(map_get "$SCHEMA_TYPE_ID_TO_TABLE_NAME" "$schema_type_id"); do
    runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/createInformationStoreStagingTable \
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
for table_name in $(map_keys "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME"); do
  csv_and_format_file_name=$(map_get "$BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME" "$table_name")
  runSQLServerCommandAsETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
    -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
    -Q \"BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/tmp/examples/data/${BASE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/tmp/examples/data/${BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)\""
done

for import_id in "${BULK_IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode BULK"
done

###############################################################################
# Ingesting correlation data                                                  #
###############################################################################
print "Inserting correlation data into the staging tables"
for table_name in $(map_keys "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME"); do
  csv_and_format_file_name=$(map_get "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "$table_name")
  runSQLServerCommandAsETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
    -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
    -Q \"BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/tmp/examples/data/${CORRELATION_BASE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/tmp/examples/data/${CORRELATION_BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', \
    FIRSTROW = 2)\""
done

print "Ingesting the CORRELATED data"
for import_id in "${IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/ingestInformationStoreRecords \
    --importMappingsFile ${IMPORT_MAPPING_FILE} \
    --importMappingId ${import_id} \
    -importMode STANDARD"
done

print "Cleaning the staging tables"
for table_name in $(map_keys "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME"); do
  csv_and_format_file_name=$(map_get "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "$table_name")
  runSQLServerCommandAsETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
    -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
    -Q \"TRUNCATE Table ${STAGING_SCHEMA}.${table_name}\""
done

###############################################################################
# Ingesting merge correlation data                                            #
###############################################################################
print "Inserting merge correlation data into into the staging tables"
for table_name in $(map_keys "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME"); do
  csv_and_format_file_name=$(map_get "$CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME" "$table_name")
  runSQLServerCommandAsETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
    -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
    -Q \"BULK INSERT ${STAGING_SCHEMA}.${table_name} \
    FROM '/tmp/examples/data/${CORRELATION_MERGE_DATA}/${csv_and_format_file_name}.csv' \
    WITH (FORMATFILE = '/tmp/examples/data/${CORRELATION_MERGE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', \
    FIRSTROW = 2)\""
done

print "Ingesting the merge correlation data"
for import_id in "${IMPORT_MAPPING_IDS[@]}"; do
  runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/ingestInformationStoreRecords \
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
    runSQLServerCommandAsETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
      -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
       -Q \"DROP TABLE ${STAGING_SCHEMA}.${table_name}\""
  done
done

set +e
