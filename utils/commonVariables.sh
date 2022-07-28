#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
# shellcheck disable=SC2034

# This file defines variables that are shared between all environments.
# It contains variables that may be changed by the end user,
# but aren't supposed to be changed unless there is a good reason for it.
# Examples:
# - image & container names
# - user names
# NOTE: this file has a dependency on the requiredEnvironmentVariables.txt, commonFunctions.sh, version and licenses.conf

source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"

###############################################################################
# Image names                                                                 #
###############################################################################
ZOOKEEPER_IMAGE_NAME="i2group/i2eng-zookeeper"
SOLR_IMAGE_NAME="solr_redhat"
SQL_SERVER_IMAGE_NAME="sqlserver_redhat"
SQL_CLIENT_IMAGE_NAME="sqlserver_client_redhat"
DB2_SERVER_IMAGE_NAME="db2_redhat"
DB2_CLIENT_IMAGE_NAME="db2_client_redhat"
LIBERTY_BASE_IMAGE_NAME="liberty_redhat"
LIBERTY_CONFIGURED_IMAGE_NAME="liberty_configured_redhat"
ETL_CLIENT_IMAGE_NAME="etlclient_redhat"
I2A_TOOLS_IMAGE_NAME="i2a_tools_redhat"
LOAD_BALANCER_IMAGE_NAME="ha_proxy_image"
CONNECTOR_IMAGE_NAME="example_connector"
CONNECTOR_IMAGE_BASE_NAME=""
REDHAT_UBI_IMAGE_NAME="registry.access.redhat.com/ubi8/ubi-minimal:8.6"
PROMETHEUS_IMAGE_NAME="i2group/i2eng-prometheus"
GRAFANA_IMAGE_NAME="grafana/grafana-oss"

###############################################################################
# Container names                                                             #
###############################################################################
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  ETL_CLIENT_CONTAINER_NAME="etlclient"
  I2A_TOOL_CONTAINER_NAME="i2atool"
  ZK1_CONTAINER_NAME="zk1"
  ZK2_CONTAINER_NAME="zk2"
  ZK3_CONTAINER_NAME="zk3"
  SOLR_CLIENT_CONTAINER_NAME="solrClient"
  SOLR1_CONTAINER_NAME="solr1"
  SOLR2_CONTAINER_NAME="solr2"
  SOLR3_CONTAINER_NAME="solr3"
  SQL_CLIENT_CONTAINER_NAME="sqlclient"
  SQL_SERVER_CONTAINER_NAME="sqlserver"
  LIBERTY1_CONTAINER_NAME="liberty1"
  LIBERTY2_CONTAINER_NAME="liberty2"
  LOAD_BALANCER_CONTAINER_NAME="load_balancer"
  CONNECTOR1_CONTAINER_NAME="exampleconnector1"
  CONNECTOR2_CONTAINER_NAME="exampleconnector2"
  PROMETHEUS_CONTAINER_NAME="prometheus"
  GRAFANA_CONTAINER_NAME="grafana"
else
  CONTAINER_VERSION_SUFFIX="${SUPPORTED_I2ANALYZE_VERSION}"
  ETL_CLIENT_CONTAINER_NAME="etlclient.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  I2A_TOOL_CONTAINER_NAME="i2atool.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  ZK1_CONTAINER_NAME="zk1.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  ZK2_CONTAINER_NAME="zk2.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  ZK3_CONTAINER_NAME="zk3.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SOLR_CLIENT_CONTAINER_NAME="solrClient.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SOLR1_CONTAINER_NAME="solr1.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SOLR2_CONTAINER_NAME="solr2.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SOLR3_CONTAINER_NAME="solr3.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SQL_CLIENT_CONTAINER_NAME="sqlclient.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  SQL_SERVER_CONTAINER_NAME="sqlserver.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  DB2_CLIENT_CONTAINER_NAME="db2client.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  DB2_SERVER_CONTAINER_NAME="db2server.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  LIBERTY1_CONTAINER_NAME="liberty1.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  LIBERTY2_CONTAINER_NAME="liberty2.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  LOAD_BALANCER_CONTAINER_NAME="load_balancer.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  CONNECTOR1_CONTAINER_NAME="exampleconnector1.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  CONNECTOR2_CONTAINER_NAME="exampleconnector2.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  PROMETHEUS_CONTAINER_NAME="prometheus.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
  GRAFANA_CONTAINER_NAME="grafana.${CONFIG_NAME}_${CONTAINER_VERSION_SUFFIX}"
fi

###############################################################################
# User names                                                                  #
###############################################################################
SOLR_ADMIN_DIGEST_USERNAME="solr"
SOLR_APPLICATION_DIGEST_USERNAME="liberty"
ZK_DIGEST_USERNAME="solr"
ZK_DIGEST_READONLY_USERNAME="readonly-user"
SA_USERNAME="sa"
DBA_USERNAME="dba"
DBB_USERNAME="dbb"
I2_ETL_USERNAME="i2etl"
ETL_USERNAME="etl"
DB2INST1_USERNAME="db2inst1"
I2_ANALYZE_USERNAME="i2analyze"
I2_GATEWAY_USERNAME="gateway.user"
PROMETHEUS_USERNAME="prometheus"
GRAFANA_USERNAME="grafana"

###############################################################################
# Liberty variables                                                           #
###############################################################################
case "${DEPLOYMENT_PATTERN}" in
"i2c_istore")
  CATALOGUE_TYPE="opal-services-is-daod"
  APPLICATION_BASE_TYPE="opal-services-is-daod"
  ;;
"i2c")
  CATALOGUE_TYPE="opal-services-daod"
  APPLICATION_BASE_TYPE="opal-services-daod"
  ;;
"schema_dev")
  CATALOGUE_TYPE="opal-services-daod"
  APPLICATION_BASE_TYPE="opal-services-daod"
  ;;
"cstore")
  CATALOGUE_TYPE="chart-storage"
  APPLICATION_BASE_TYPE="opal-services-is"
  ;;
"i2c_cstore")
  CATALOGUE_TYPE="chart-storage-daod"
  APPLICATION_BASE_TYPE="opal-services-is-daod"
  ;;
"istore")
  CATALOGUE_TYPE="opal-services-is"
  APPLICATION_BASE_TYPE="opal-services-is"
  ;;
esac

###############################################################################
# Gateway variables                                                           #
###############################################################################
declare -gA GATEWAY_SHORT_NAME_SET

###############################################################################
# User variables                                                              #
###############################################################################
if [[ -z "${USER}" ]]; then
  USER="$(whoami)"
fi

source "${ANALYZE_CONTAINERS_ROOT_DIR}/licenses.conf"
