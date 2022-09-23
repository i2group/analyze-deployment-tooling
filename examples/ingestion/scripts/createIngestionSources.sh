#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

###############################################################################
# Etl variables                                                               #
###############################################################################
# Ingestion sources are defined as:
# [ingestion source description]=ingestion_source_name
declare -A INGESTION_SOURCES
INGESTION_SOURCES=(
  ["Example Ingestion Source 1"]=EXAMPLE_1
  ["Example Ingestion Source 2"]=EXAMPLE_2
)

###############################################################################
# Creating the ingestion sources                                              #
###############################################################################
print "Adding Information Store Ingestion Source(s)"

for ingestion_source_description in "${!INGESTION_SOURCES[@]}"; do
  ingestion_source_name="${INGESTION_SOURCES["${ingestion_source_description}"]}"

  run_etl_toolkit_tool_as_i2_etl bash -c "/opt/i2/etltoolkit/addInformationStoreIngestionSource \
        --ingestionSourceDescription ${ingestion_source_description} \
        --ingestionSourceName ${ingestion_source_name}"
done
