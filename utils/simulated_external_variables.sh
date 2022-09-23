#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
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
DB2_CLIENT_HOST_NAME="db2client"
DB2_SERVER_HOST_NAME="db2server"
LIBERTY1_HOST_NAME="liberty1"
LIBERTY2_HOST_NAME="liberty2"
I2A_TOOL_HOST_NAME="i2atool"
LOAD_BALANCER_HOST_NAME="loadbalancer"
PROMETHEUS_HOST_NAME="prometheus"
GRAFANA_HOST_NAME="grafana"
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
DB2_CLIENT_FQDN="${DB2_CLIENT_HOST_NAME}.${DOMAIN_NAME}"
DB2_SERVER_FQDN="${DB2_SERVER_HOST_NAME}.${DOMAIN_NAME}"
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
DB_SSL_CONNECTION="false"
SOLR_ZOO_SSL_CONNECTION="false"
LIBERTY_SSL_CONNECTION="true"
GATEWAY_SSL_CONNECTION="true"
PROMETHEUS_SSL_CONNECTION="true"

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
CONNECTOR1_APP_PORT="3443"
CONNECTOR2_APP_PORT="3443"

if [[ -z "${DB_DIALECT}" ]]; then
  # Default to sqlserver
  DB_DIALECT="sqlserver"
fi

case "${DB_DIALECT}" in
db2)
  DB_PORT="50000"
  ;;
sqlserver)
  DB_PORT="1433"
  ;;
\?)
  echo "Invalid option: ${DB_DIALECT}"
  exit 1
  ;;
esac

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

case "${DB_DIALECT}" in
db2)
  DB_INSTALL_DIR="/opt/ibm/db2/V11.5"
  DB_LOCATION_DIR="/database/config/db2inst1"
  DB_BACKUP_FILE_NAME="ISTORE"
  SQLCMD="${DB_INSTALL_DIR}/bin/db2"
  SQLCMD_FLAGS="-tsvmf"
  DB_NODE="dbnode"
  ;;
sqlserver)
  DB_INSTALL_DIR="/opt/mssql-tools"
  DB_LOCATION_DIR="/var/opt/mssql/data"
  DB_BACKUP_FILE_NAME="ISTORE.bak"
  SQLCMD="${DB_INSTALL_DIR}/bin/sqlcmd"
  if [[ "$DB_SSL_CONNECTION" == true ]]; then
    SQLCMD_FLAGS="-N -b"
  else
    SQLCMD_FLAGS="-b"
  fi
  ;;
\?)
  echo "Invalid option: ${DB_DIALECT}"
  exit 1
  ;;
esac

DB_NAME="ISTORE"
DB_OS_TYPE="UNIX"
DB_CONTAINER_BACKUP_DIR="/backup"

###############################################################################
# URIs                                                                        #
###############################################################################
BASE_URI="https://${I2_ANALYZE_FQDN}:${HOST_PORT_I2ANALYZE_SERVICE}"
FRONT_END_URI="${BASE_URI}/opal"

###############################################################################
# User names                                                                  #
###############################################################################
I2_ANALYZE_ADMIN="I2AnalyzeConfigDevAdmin"

###############################################################################
# Root Paths                                                                  #
###############################################################################
LOCAL_USER_CHANGE_SETS_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/change-sets"
LOCAL_USER_CONFIG_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/configuration"
LOCAL_CONFIG_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/.configuration"
GENERATED_LOCAL_CONFIG_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/.configuration-generated"
LOCAL_LIB_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/.i2a-extensions" # TODO: only used in upgrade, should be removed together when removing it from upgrade.
LOCAL_GENERATED_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/configs/${CONFIG_NAME}/database-scripts/generated"

PRE_REQS_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/pre-reqs"
LOCAL_I2ANALYZE_DIR="${PRE_REQS_DIR}/i2analyze"
LOCAL_TOOLKIT_DIR="${LOCAL_I2ANALYZE_DIR}/toolkit"
DATA_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/i2a-data"
BACKUP_DIR="${ANALYZE_CONTAINERS_ROOT_DIR}/backups/${CONFIG_NAME}"

TOOLKIT_APPLICATION_DIR="${LOCAL_TOOLKIT_DIR}/application"

ENVIRONMENT="config-dev"
