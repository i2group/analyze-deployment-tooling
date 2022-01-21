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

###############################################################################
# Etl variables                                                               #
###############################################################################
# Ingestion sources are defined as:
# [ingestion source description]=ingestion_source_name
declare -A INGESTION_SOURCES
INGESTION_SOURCES=( 
    [Example Ingestion Source 1]=EXAMPLE_1
    [Example Ingestion Source 2]=EXAMPLE_2
)

###############################################################################
# Creating the ingestion sources                                              #
###############################################################################
print "Adding Information Store Ingestion Source(s)"

for ingestion_source_description in "${!INGESTION_SOURCES[@]}"; do
    ingestion_source_name="${INGESTION_SOURCES[${ingestion_source_description}]}"
    
    runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/addInformationStoreIngestionSource \
        --ingestionSourceDescription ${ingestion_source_description} \
        --ingestionSourceName ${ingestion_source_name}"
done
