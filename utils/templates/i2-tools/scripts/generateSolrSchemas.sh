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

source "$(dirname "$0")/utils/common_functions.sh"

initialize

function runGenerateSolrSchemaCLI() {
	local collection_name="$1"

	java "${JVM_ARGS[@]}" -cp "${JAR_PATH}/*:${JDBC_DRIVERS_PATH}/*:${LOG4J_PATH}:${CLASSES_PATH}" \
		"com.i2group.disco.solr.schema.generate.internal.GenerateSolrSchemaCLI" \
		-solrCollectionType "${collection_name}" \
		-templateFilePath "${CONFIG_DIR}/solr/schema-template-definition.xml" \
		-schemaFilePath "${CONFIG_DIR}/solr/generated_config/${collection_name}_index/managed-schema" \
		-force \
		-stacktrace
}

function runGenerateSolrConfigCLI() {
	local collection_name="$1"

	java "${JVM_ARGS[@]}" -cp "${JAR_PATH}/*:${JDBC_DRIVERS_PATH}/*:${LOG4J_PATH}:${CLASSES_PATH}" \
		"com.i2group.disco.solr.solrconfig.GenerateSolrConfigCLI" \
		-fp "${CONFIG_DIR}/solr/generated_config/${collection_name}_index/solrconfig.xml" \
		-force \
		-stacktrace
}

COLLECTION_NAMES=("main" "daod" "highlight" "chart" "match" "vq")

for collection_name in "${COLLECTION_NAMES[@]}"; do
	runGenerateSolrSchemaCLI "${collection_name}"
	runGenerateSolrConfigCLI "${collection_name}"
done

set +e
