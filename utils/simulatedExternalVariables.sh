#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2021, IBM Corporation
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
# shellcheck disable=SC2034

# This file defines variables that are only used for the configuration development environment.
# It containers variables that should NOT be changed by the end-user.
# Examples:
# - Network Security Variables
# - Ports
# - Connection Information
# - Paths, e.g LOCAL_CONFIG_DIR, LOCAL_GENERATED_DIR
# NOTE: this file does NOT have any dependencies

###############################################################################
# License Variables                                                           #
###############################################################################
LIC_AGREEMENT=REJECT
MSSQL_PID=REJECT
ACCEPT_EULA=N

###############################################################################
# Domain name                                                                 #
###############################################################################
DOMAIN_NAME="eia"

###############################################################################
# Host names                                                                  #
###############################################################################
ZK1_HOST_NAME="zk1"
ZK2_HOST_NAME="zk2"
ZK3_HOST_NAME="zk3"
SOLR_CLIENT_HOST_NAME="solrClient"
SOLR1_HOST_NAME="solr1"
SOLR2_HOST_NAME="solr2"
SOLR3_HOST_NAME="solr3"
SQL_CLIENT_HOST_NAME="sqlclient"
SQL_SERVER_HOST_NAME="sqlserver"
LIBERTY1_HOST_NAME="liberty1"
LIBERTY2_HOST_NAME="liberty2"
I2A_TOOL_HOST_NAME="i2atool"
LOAD_BALANCER_HOST_NAME="loadbalancer"
CONNECTOR1_HOST_NAME="exampleconnector1"
CONNECTOR2_HOST_NAME="exampleconnector2"
I2ANALYZE_HOST_NAME="i2analyze"

###############################################################################
# Fully qualified domain names                                                #
###############################################################################
ZK1_FQDN="${ZK1_HOST_NAME}.${DOMAIN_NAME}"
ZK2_FQDN="${ZK2_HOST_NAME}.${DOMAIN_NAME}"
ZK3_FQDN="${ZK3_HOST_NAME}.${DOMAIN_NAME}"
SOLR_CLIENT_FQDN="${SOLR_CLIENT_HOST_NAME}.${DOMAIN_NAME}"
SOLR1_FQDN="${SOLR1_HOST_NAME}.${DOMAIN_NAME}"
SOLR2_FQDN="${SOLR2_HOST_NAME}.${DOMAIN_NAME}"
SOLR3_FQDN="${SOLR3_HOST_NAME}.${DOMAIN_NAME}"
SQL_CLIENT_FQDN="${SQL_CLIENT_HOST_NAME}.${DOMAIN_NAME}"
SQL_SERVER_FQDN="${SQL_SERVER_HOST_NAME}.${DOMAIN_NAME}"
LIBERTY1_FQDN="${LIBERTY1_HOST_NAME}.${DOMAIN_NAME}"
LIBERTY2_FQDN="${LIBERTY2_HOST_NAME}.${DOMAIN_NAME}"
I2A_TOOL_FQDN="${I2A_TOOL_HOST_NAME}.${DOMAIN_NAME}"
I2_ANALYZE_FQDN="${I2ANALYZE_HOST_NAME}.${DOMAIN_NAME}"
LOAD_BALANCER_FQDN="${LOAD_BALANCER_HOST_NAME}.${DOMAIN_NAME}"
CONNECTOR1_FQDN="${CONNECTOR1_HOST_NAME}.${DOMAIN_NAME}"
CONNECTOR2_FQDN="${CONNECTOR2_HOST_NAME}.${DOMAIN_NAME}"

###############################################################################
# AWS Variables                                                               #
###############################################################################

AWS_REGION="eu-west-2"
ECR_BASE_NAME="011520264122.dkr.ecr.eu-west-2.amazonaws.com"

EXTRA_ARGS=()
if [[ "${AWS_DEPLOY}" == "false" ]]; then
  EXTRA_ARGS+=("--net")
  EXTRA_ARGS+=("${DOMAIN_NAME}")
fi

###############################################################################
# Network Security Variables                                                  #
###############################################################################
DB_SSL_CONNECTION="false"
SOLR_ZOO_SSL_CONNECTION="false"
LIBERTY_SSL_CONNECTION="true"
GATEWAY_SSL_CONNECTION="true"

###############################################################################
# Ports                                                                       #
###############################################################################
ZK_CLIENT_PORT="2181"
ZK_SECURE_CLIENT_PORT="2281"
I2_ANALYZE_PORT="9046"
LIBERTY1_PORT="9045"
LIBERTY1_DEBUG_PORT="7777"
LIBERTY2_PORT="9044"
LIBERTY2_DEBUG_PORT="7778"
SOLR_PORT="8983"
ZK_PORT="8080"
CONNECTOR1_APP_PORT="3700"
CONNECTOR2_APP_PORT="3700"
DB_PORT="1433"

if [[ "$SOLR_ZOO_SSL_CONNECTION" == true ]]; then
  ZK_ACTIVE_PORT="${ZK_SECURE_CLIENT_PORT}"
  SOLR1_BASE_URL="https://${SOLR1_FQDN}:${SOLR_PORT}"
else
  ZK_ACTIVE_PORT="${ZK_CLIENT_PORT}"
  SOLR1_BASE_URL="http://${SOLR1_FQDN}:${SOLR_PORT}"
fi

###############################################################################
# Connection Information                                                      #
###############################################################################
ZK_MEMBERS="${ZK1_FQDN}:${ZK_ACTIVE_PORT}"
ZOO_SERVERS="server.1=${ZK1_FQDN}:2888:3888"

SOLR_CLUSTER_ID="is_cluster"
ZK_HOST="${ZK_MEMBERS}/${SOLR_CLUSTER_ID}"

###############################################################################
# Database variables                                                          #
###############################################################################
DB_DIALECT="sqlserver"
DB_INSTALL_DIR="/opt/mssql-tools"
DB_LOCATION_DIR="/var/opt/mssql/data"
DB_CONTAINER_BACKUP_DIR="/backup"
DB_BACKUP_FILE_NAME="ISTORE.bak"
DB_NAME="ISTORE"
DB_OS_TYPE="UNIX"
SQLCMD="${DB_INSTALL_DIR}/bin/sqlcmd"
if [[ "$DB_SSL_CONNECTION" == true ]]; then
  SQLCMD_FLAGS="-N -b"
else
  SQLCMD_FLAGS="-b"
fi

###############################################################################
# URIs                                                                        #
###############################################################################
BASE_URI="https://${I2_ANALYZE_FQDN}:${HOST_PORT_I2ANALYZE_SERVICE}"
FRONT_END_URI="${BASE_URI}/opal"

###############################################################################
# Root Paths                                                                  #
###############################################################################
# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

LOCAL_USER_CONFIG_DIR="${ROOT_DIR}/configs/${CONFIG_NAME}/configuration"
LOCAL_CONFIG_DIR="${ROOT_DIR}/.configuration"
GENERATED_LOCAL_CONFIG_DIR="${ROOT_DIR}/.configuration-generated"
LOCAL_GENERATED_DIR="${ROOT_DIR}/configs/${CONFIG_NAME}/database-scripts/generated"

PRE_REQS_DIR="${ROOT_DIR}/pre-reqs"
LOCAL_I2ANALYZE_DIR="${PRE_REQS_DIR}/i2analyze"
LOCAL_TOOLKIT_DIR="${LOCAL_I2ANALYZE_DIR}/toolkit"
DATA_DIR="${ROOT_DIR}/i2a-data"

TOOLKIT_APPLICATION_DIR="${LOCAL_TOOLKIT_DIR}/application"

ENVIRONMENT="config-dev"