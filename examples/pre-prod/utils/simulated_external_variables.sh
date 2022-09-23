#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
# shellcheck disable=SC2034

# This file defines variables that are only used for the pre-prod environment.
# It containers variables that may be changed by the end-user.
# Examples:
# - Network Security Variables
# - Ports
# - Connection Information
# - Paths, e.g LOCAL_CONFIG_DIR, LOCAL_GENERATED_DIR
# NOTE: this file does NOT have any dependencies

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
PROMETHEUS_HOST_NAME="prometheus"
GRAFANA_HOST_NAME="grafana"

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
PROMETHEUS_FQDN="${PROMETHEUS_HOST_NAME}.${DOMAIN_NAME}"
GRAFANA_FQDN="${GRAFANA_HOST_NAME}.${DOMAIN_NAME}"

EXTRA_ARGS=()
EXTRA_ARGS+=("--net")
EXTRA_ARGS+=("${DOMAIN_NAME}")

###############################################################################
# Network Security Variables                                                  #
###############################################################################
DB_SSL_CONNECTION="true"
SOLR_ZOO_SSL_CONNECTION="true"
LIBERTY_SSL_CONNECTION="true"
GATEWAY_SSL_CONNECTION="true"
PROMETHEUS_SSL_CONNECTION="true"

###############################################################################
# Ports                                                                       #
###############################################################################
ZK_CLIENT_PORT=2181
ZK_SECURE_CLIENT_PORT=2281
I2_ANALYZE_PORT=9046
LIBERTY1_PORT=9045
LIBERTY1_DEBUG_PORT=7777
LIBERTY2_PORT=9044
LIBERTY2_DEBUG_PORT=7778
SOLR_PORT=8983
CONNECTOR1_APP_PORT=3443
CONNECTOR2_APP_PORT=3443
DB_PORT=1433
INTERNAL_LIBERTY_PORT=9080
INTERNAL_SECURE_LIBERTY_PORT=9443

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
ZK_MEMBERS="${ZK1_FQDN}:${ZK_ACTIVE_PORT},${ZK2_FQDN}:${ZK_ACTIVE_PORT},${ZK3_FQDN}:${ZK_ACTIVE_PORT}" # hardcoded
SOLR_CLUSTER_ID="is_cluster"
ZK_HOST="${ZK_MEMBERS}/${SOLR_CLUSTER_ID}"
ZOO_SERVERS="server.1=${ZK1_FQDN}:2888:3888 server.2=${ZK2_FQDN}:2888:3888 server.3=${ZK3_FQDN}:2888:3888"

if [[ "$LIBERTY_SSL_CONNECTION" == "true" ]]; then
  LIBERTY1_STANZA="${LIBERTY1_FQDN}:${INTERNAL_SECURE_LIBERTY_PORT}"
  LIBERTY2_STANZA="${LIBERTY2_FQDN}:${INTERNAL_SECURE_LIBERTY_PORT}"
  LIBERTY1_LB_STANZA="${LIBERTY1_STANZA} ssl verify none"
  LIBERTY2_LB_STANZA="${LIBERTY2_STANZA} ssl verify none"
  LIBERTY_SSL="ssl"
else
  LIBERTY1_STANZA="${LIBERTY1_FQDN}:${INTERNAL_LIBERTY_PORT}"
  LIBERTY2_STANZA="${LIBERTY2_FQDN}:${INTERNAL_LIBERTY_PORT}"
  LIBERTY1_LB_STANZA="${LIBERTY1_STANZA}"
  LIBERTY2_LB_STANZA="${LIBERTY2_STANZA}"
  LIBERTY_SSL="no-ssl"
fi

###############################################################################
# Database variables                                                          #
###############################################################################
HOST_PORT_DB="1433"
DB_DIALECT="sqlserver"
DB_INSTALL_DIR="/opt/mssql-tools"
DB_LOCATION_DIR="/var/opt/mssql/data"
DATA_DIR="${LOCAL_TOOLKIT_DIR}/examples/data"
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
# Prometheus variables                                                        #
###############################################################################
HOST_PORT_PROMETHEUS="9090"

###############################################################################
# Grafana variables                                                           #
###############################################################################
HOST_PORT_GRAFANA="3500"

###############################################################################
# URIs                                                                        #
###############################################################################
BASE_URI="https://${I2_ANALYZE_FQDN}:${I2_ANALYZE_PORT}"
FRONT_END_URI="${BASE_URI}/opal"
LOAD_BALANCER_STATS_URI="${BASE_URI}/haproxy_stats;csv;norefresh"

###############################################################################
# User names                                                                  #
###############################################################################
I2_ANALYZE_ADMIN="Jenny"

###############################################################################
# Root Paths                                                                  #
###############################################################################
PRE_REQS_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/pre-reqs"
PRE_PROD_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod"

LOCAL_CHANGE_SETS_DIR="${PRE_PROD_DIR}/change-sets"
LOCAL_CONFIG_DIR="${PRE_PROD_DIR}/configuration"
LOCAL_DATABASE_SCRIPTS_DIR="${PRE_PROD_DIR}/database-scripts"
LOCAL_GENERATED_DIR="${LOCAL_DATABASE_SCRIPTS_DIR}/generated"
LOCAL_I2ANALYZE_DIR="${PRE_REQS_DIR}/i2analyze"
LOCAL_TOOLKIT_DIR="${LOCAL_I2ANALYZE_DIR}/toolkit"

PRE_REQS_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/pre-reqs"
LOCAL_I2ANALYZE_DIR="${PRE_REQS_DIR}/i2analyze"
LOCAL_TOOLKIT_DIR="${LOCAL_I2ANALYZE_DIR}/toolkit"
DATA_DIR="${LOCAL_TOOLKIT_DIR}/examples/data"

TOOLKIT_APPLICATION_DIR="${LOCAL_TOOLKIT_DIR}/application"

ENVIRONMENT="pre-prod"
DEPLOYMENT_PATTERN="i2c_istore"
