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

# Loading common variables and functions
source ./utils/commonVariables.sh
source ./utils/commonFunctions.sh

###############################################################################
# Variables                                                                   #
###############################################################################
LOCAL_CONFIG_COMMON_DIR="${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes"
LOCAL_CONFIG_OPAL_SERVICES_DIR="${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes"
LOCAL_SOLR_CONFIG_DIR="${LOCAL_CONFIG_DIR}/solr"
TOOLKIT_CONIFG_EXAMPLES_SCHEMAS="${LOCAL_TOOLKIT_DIR}/examples/schemas/en_US"
ALL_PATTERNS_CONFIG_DIR="${LOCAL_TOOLKIT_DIR}/examples/configurations/all-patterns/configuration"

###############################################################################
# Function definitions                                                        #
###############################################################################
function createCleanBaseConfiguration() {
  print "Clearing down configuration"
  deleteFolderIfExists "${LOCAL_CONFIG_DIR}"

  print "Copying all-patterns Configuration to ${LOCAL_CONFIG_DIR}"
  mkdir -p "${LOCAL_CONFIG_DIR}"
  cp -pr "${ALL_PATTERNS_CONFIG_DIR}/"* "${LOCAL_CONFIG_DIR}"
}

function setProperties() {
  print "Setting schema and charting schema"
  cp -pr "${TOOLKIT_CONIFG_EXAMPLES_SCHEMAS}/law-enforcement-schema.xml" "${LOCAL_CONFIG_COMMON_DIR}/schema.xml"
  cp -pr "${TOOLKIT_CONIFG_EXAMPLES_SCHEMAS}/law-enforcement-schema-charting-schemes.xml" "${LOCAL_CONFIG_COMMON_DIR}/schema-charting-scheme.xml"
  sed -i -e "/^SchemaResource=/ s/=.*/=schema.xml/" "${LOCAL_CONFIG_COMMON_DIR}/ApolloServerSettingsMandatory.properties"
  sed -i -e "/^ChartingSchemesResource=/ s/=.*/=schema-charting-scheme.xml/" "${LOCAL_CONFIG_COMMON_DIR}/ApolloServerSettingsMandatory.properties"
}

function configureFormBasedAuth() {
  print "Configuring form based authentication"
  echo '<?xml version="1.0" encoding="UTF-8"?><server>
    <webAppSecurity overrideHttpAuthMethod="FORM" allowAuthenticationFailOverToAuthMethod="FORM"  loginFormURL="opal/login.html" loginErrorURL="opal/login.html?failed"/>
</server>' >"${LOCAL_CONFIG_COMMON_DIR}/server.extensions.xml"

  # This should not be necessary as the above should override the auth method. See: https://github.com/OpenLiberty/open-liberty/issues/14844
  sed -i -e "s/^AlwaysAllowLogout=false/AlwaysAllowLogout=true/" "${LOCAL_CONFIG_OPAL_SERVICES_DIR}/DiscoServerSettingsCommon.properties"
}

function createSolrConfiguration() {
  print "Creating solr configuration"
  mkdir -p "${LOCAL_CONFIG_DIR}/solr"
  cp -pr "${LOCAL_TOOLKIT_DIR}/solr-mods/managed-schemas/${SOLR_LOCALE}/." "${LOCAL_SOLR_CONFIG_DIR}"

  cp "${LOCAL_TOOLKIT_DIR}/solr-mods/solrconfig.xml" "${LOCAL_SOLR_CONFIG_DIR}/chart_index"
  cp "${LOCAL_TOOLKIT_DIR}/solr-mods/solrconfig.xml" "${LOCAL_SOLR_CONFIG_DIR}/daod_index"
  cp "${LOCAL_TOOLKIT_DIR}/solr-mods/solrconfig.xml" "${LOCAL_SOLR_CONFIG_DIR}/highlight_index"
  cp "${LOCAL_TOOLKIT_DIR}/solr-mods/solrconfig.xml" "${LOCAL_SOLR_CONFIG_DIR}/main_index"
  cp "${LOCAL_TOOLKIT_DIR}/solr-mods/solrconfig.xml" "${LOCAL_SOLR_CONFIG_DIR}/match_index"

  cp "${LOCAL_TOOLKIT_DIR}/examples/solr-resources/solr-synonyms/synonyms-${SOLR_LOCALE}.txt" "${LOCAL_SOLR_CONFIG_DIR}/chart_index"
  cp "${LOCAL_TOOLKIT_DIR}/examples/solr-resources/solr-synonyms/synonyms-${SOLR_LOCALE}.txt" "${LOCAL_SOLR_CONFIG_DIR}/daod_index"
  cp "${LOCAL_TOOLKIT_DIR}/examples/solr-resources/solr-synonyms/synonyms-${SOLR_LOCALE}.txt" "${LOCAL_SOLR_CONFIG_DIR}/highlight_index"
  cp "${LOCAL_TOOLKIT_DIR}/examples/solr-resources/solr-synonyms/synonyms-${SOLR_LOCALE}.txt" "${LOCAL_SOLR_CONFIG_DIR}/main_index"
  cp "${LOCAL_TOOLKIT_DIR}/examples/solr-resources/solr-synonyms/synonyms-${SOLR_LOCALE}.txt" "${LOCAL_SOLR_CONFIG_DIR}/match_index"
}

function copyJdbcDriversToConfiguration() {
  cp ./utils/templates/connectors.json "${LOCAL_CONFIG_OPAL_SERVICES_DIR}/connectors.json"
  cp -pr "${PRE_REQS_DIR}/jdbc-drivers" "${LOCAL_CONFIG_DIR}/environment/common"
}

###############################################################################
# Re-creating local i2Analyze configuration                                   #
###############################################################################
createCleanBaseConfiguration

###############################################################################
# Setting properties in configuration                                         #
###############################################################################
setProperties

###############################################################################
# Configuring Form Based Auth                                                 #
###############################################################################
configureFormBasedAuth

###############################################################################
# Creating Solr configuration                                                 #
###############################################################################
createSolrConfiguration

###############################################################################
# Placing jdbc drivers into configuration                                     #
###############################################################################
copyJdbcDriversToConfiguration

print "Configuration has been successfully created"
set +e
