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

# Load common variables and functions
source ./utils/commonVariables.sh
source ./utils/commonFunctions.sh

###############################################################################
# Building load balancer image                                                #
###############################################################################
print "Building load balancer image"
docker build -t "${LOAD_BALANCER_IMAGE_NAME}" "${IMAGES_DIR}/ha_proxy"

###############################################################################
# Building Liberty base image                                                 #
###############################################################################
print "Building Liberty base image"
docker build -t "${LIBERTY_BASE_IMAGE_NAME}" "${IMAGES_DIR}/liberty_ubi_base"

###############################################################################
# Building Solr image                                                         #
###############################################################################
print "Building Solr image"
docker build -t "${SOLR_IMAGE_NAME}" "${IMAGES_DIR}/solr_redhat"

###############################################################################
# Building ZooKeeper image                                                    #
###############################################################################
print "Building ZooKeeper image"
docker build -t "${ZOOKEEPER_IMAGE_NAME}" "${IMAGES_DIR}/zookeeper_redhat"

###############################################################################
# Building SQL Server image                                                   #
###############################################################################
print "Building SQL Server image"
docker build -t "${SQL_SERVER_IMAGE_NAME}" "${IMAGES_DIR}/sql_server"

###############################################################################
# Building SQL Client image                                                   #
###############################################################################
print "Building SQL Client image"
docker build -t "${SQL_CLIENT_IMAGE_NAME}" "${IMAGES_DIR}/sql_client"

###############################################################################
# Building i2 Analyze Tool image                                              #
###############################################################################
print "Building i2 Analyze Tool image"
docker image build -t "${I2A_TOOLS_IMAGE_NAME}" "${IMAGES_DIR}/i2a_tools" \
  --build-arg USER_UID="$(id -u "${USER}")"

###############################################################################
# Building ETL Client image                                                   #
###############################################################################
print "Building ETL Client image"
if [[ -d "${IMAGES_DIR}/etl_client/etltoolkit/classes" ]]; then
  echo "Clearing down etltoolkit classes folder"
  rm -rf "${IMAGES_DIR}/etl_client/etltoolkit/classes"
fi
echo "Populating etltoolkit classes folder"
mkdir "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_CONFIG_DIR}/i2-tools/classes/"* "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_CONFIG_OPAL_SERVICES_IS_DIR}/InfoStoreNamesSQLServer.properties" \
  "${IMAGES_DIR}/etl_client/etltoolkit/classes"
docker build -t "${ETL_CLIENT_IMAGE_NAME}" "${IMAGES_DIR}/etl_client" \
  --build-arg USER_UID="$(id -u "${USER}")" \
  --build-arg BASE_IMAGE="${I2A_TOOLS_IMAGE_NAME}"

###############################################################################
# Building Example connector image                                            #
###############################################################################
docker build -t "${CONNECTOR_IMAGE_NAME}" "${IMAGES_DIR}/example_connector"