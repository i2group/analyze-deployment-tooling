#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
set -e

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"

ROOT_DIR=$(pwd)/../../..

# Loading common variables and functions
source ./commonFunctions.sh
source ./serverFunctions.sh
source ./clientFunctions.sh
source ./commonVariables.sh

TARGET_DIR="${1}"
DEPLOYMENT="${2}"
TOOLKIT_APPLICATION_DIR="${LOCAL_TOOLKIT_DIR}/application"
THIRD_PARTY_DIR="${TARGET_DIR}/third-party-dependencies"

###############################################################################
# Function definitions                                                        #
###############################################################################
function populateLibertyApplication() {
  print "Populating static liberty application folder"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/targets/opal-services" "${TARGET_DIR}"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/dependencies/icons" "${TARGET_DIR}/opal-services"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/shared/lib" "${THIRD_PARTY_DIR}/resources/i2-common"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/dependencies/tai" "${THIRD_PARTY_DIR}/resources/security"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/server/." "${TARGET_DIR}/"
}

function createDataSourceProperties() {
  print "Creating DataSource.properties file"
  {
    echo "DataSourceId=$(uuidgen)"
    echo "DataSourceName=Information Store"
    echo "TopologyId=infostore"
    echo "AppName=opal-services"
    echo "IsMonitored=true"
  } >>"${TARGET_DIR}/opal-services/WEB-INF/classes/DataSource.properties"
}

function createDeploymentSpecificFiles() {
  print "Creating deployment specific files"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/target-mods/${CATALOGUE_TYPE}/catalog.json" "${TARGET_DIR}/opal-services/WEB-INF/classes/"
  cp -pr "${TOOLKIT_APPLICATION_DIR}/fragment-mods/${APPLICATION_BASE_TYPE}/WEB-INF/web.xml" "${TARGET_DIR}/web-app-files/web.xml"
  sed -i.bak -e '1s/^/<?xml version="1.0" encoding="UTF-8"?><web-app xmlns="http:\/\/java.sun.com\/xml\/ns\/javaee" xmlns:xsi="http:\/\/www.w3.org\/2001\/XMLSchema-instance" xsi:schemaLocation="http:\/\/java.sun.com\/xml\/ns\/javaee http:\/\/java.sun.com\/xml\/ns\/javaee\/web-app_3_0.xsd" id="WebApp_ID" version="3.0"> \
    <display-name>opal<\/display-name>/' "${TARGET_DIR}/web-app-files/web.xml"
  echo '</web-app>' >>"${TARGET_DIR}/web-app-files/web.xml"
}

###############################################################################
# Set deployment specific variables                                           #
###############################################################################
case "${DEPLOYMENT}" in
"information-store-daod-opal")
  CATALOGUE_TYPE="opal-services-is-daod"
  APPLICATION_BASE_TYPE="opal-services-is-daod"
  ;;
"daod-opal")
  CATALOGUE_TYPE="opal-services-daod"
  APPLICATION_BASE_TYPE="opal-services-daod"
  ;;
"chart-storage")
  CATALOGUE_TYPE="chart-storage"
  APPLICATION_BASE_TYPE="opal-services-is"
  ;;
"chart-storage-daod")
  CATALOGUE_TYPE="chart-storage-daod"
  APPLICATION_BASE_TYPE="opal-services-is-daod"
  ;;
"information-store-opal")
  CATALOGUE_TYPE="opal-services-is"
  APPLICATION_BASE_TYPE="opal-services-is"
  ;;
*)
  CATALOGUE_TYPE="opal-services-is-daod"
  APPLICATION_BASE_TYPE="opal-services-is-daod"
  ;;
esac

###############################################################################
# Create required directories                                                 #
###############################################################################
mkdir -p "${TARGET_DIR}"
mkdir -p "${THIRD_PARTY_DIR}/resources"
mkdir -p "${THIRD_PARTY_DIR}/resources/i2-common"
mkdir -p "${THIRD_PARTY_DIR}/resources/security"
mkdir -p "${THIRD_PARTY_DIR}/resources/jdbc"

###############################################################################
# Populate liberty application                                                #
###############################################################################
populateLibertyApplication

###############################################################################
# Create datasource.properties file                                           #
###############################################################################
createDataSourceProperties

###############################################################################
# Create deployment specific files                                            #
###############################################################################
createDeploymentSpecificFiles

set +e
