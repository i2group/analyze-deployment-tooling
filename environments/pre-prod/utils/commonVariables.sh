#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
# shellcheck disable=SC2034

###############################################################################
# License Variables                                                           #
###############################################################################
LIC_AGREEMENT=REJECT
MSSQL_PID=REJECT
ACCEPT_EULA="N"

###############################################################################
# AWS Support Variables - For future use do not change                        #
###############################################################################
AWS_SECRETS=false
AWS_IMAGES=false
AWS_DEPLOY=false

###############################################################################
# Network Security Variables                                                  #
###############################################################################
DB_SSL_CONNECTION=true
SOLR_ZOO_SSL_CONNECTION=true
LIBERTY_SSL_CONNECTION=true
GATEWAY_SSL_CONNECTION=true

###############################################################################
# Domain name - AWS deployment for future use                                 #
###############################################################################
if [[ "$AWS_SECRETS" == true ]]; then
  DOMAIN_NAME="i2a-stack-i2analyze"
else
  DOMAIN_NAME="eia"
fi

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
# Ports                                                                       #
###############################################################################
ZK_CLIENT_PORT=2181
ZK_SECURE_CLIENT_PORT=2281
I2_ANALYZE_PORT=9046
LIBERTY1_PORT=9045
LIBERTY2_PORT=9044
SOLR_PORT=8983
CONNECTOR1_APP_PORT=3700
CONNECTOR2_APP_PORT=3700

###############################################################################
# Connection Information                                                      #
###############################################################################

if [[ "$SOLR_ZOO_SSL_CONNECTION" == true ]]; then
  ZK_ACTIVE_PORT="${ZK_SECURE_CLIENT_PORT}"
  SOLR1_BASE_URL="https://${SOLR1_FQDN}:${SOLR_PORT}"
  ZK1_ADMIN_URL="https://${ZK1_FQDN}:8080/commands"
  ZK2_ADMIN_URL="https://${ZK2_FQDN}:8080/commands"
  ZK3_ADMIN_URL="https://${ZK3_FQDN}:8080/commands"
else
  ZK_ACTIVE_PORT="${ZK_CLIENT_PORT}"
  SOLR1_BASE_URL="http://${SOLR1_FQDN}:${SOLR_PORT}"
  ZK1_ADMIN_URL="http://${ZK1_FQDN}:8080/commands"
  ZK2_ADMIN_URL="http://${ZK2_FQDN}:8080/commands"
  ZK3_ADMIN_URL="http://${ZK3_FQDN}:8080/commands"
fi

if [[ "$AWS_DEPLOY" == true ]]; then
  ZK_MEMBERS="${ZK1_FQDN}:${ZK_ACTIVE_PORT}"
else
  ZK_MEMBERS="${ZK1_FQDN}:${ZK_ACTIVE_PORT},${ZK2_FQDN}:${ZK_ACTIVE_PORT},${ZK3_FQDN}:${ZK_ACTIVE_PORT}"
fi
SOLR_CLUSTER_ID="is_cluster"
ZK_HOST="${ZK_MEMBERS}/${SOLR_CLUSTER_ID}"
SOLR_HEALTH_CHECK_URL="${SOLR1_BASE_URL}/solr/#/admin/info/health"

if [[ "$LIBERTY_SSL_CONNECTION" == true ]]; then
  LIBERTY1_LB_STANZA="${LIBERTY1_FQDN}:9443 ssl verify none"
  LIBERTY2_LB_STANZA="${LIBERTY2_FQDN}:9443 ssl verify none"
else
  LIBERTY1_LB_STANZA="${LIBERTY1_FQDN}:9080"
  LIBERTY2_LB_STANZA="${LIBERTY2_FQDN}:9080"
fi
ECR_BASE_NAME="011520264122.dkr.ecr.eu-west-2.amazonaws.com"

###############################################################################
# Localisation variables                                                      #
###############################################################################
SOLR_LOCALE="en_US"

###############################################################################
# Image names                                                                 #
###############################################################################
if [[ "$AWS_IMAGES" == true ]]; then
  ZOOKEEPER_IMAGE_NAME="${ECR_BASE_NAME}/zookeeper_redhat"
  SOLR_IMAGE_NAME="${ECR_BASE_NAME}/solr_redhat"
  SQL_SERVER_IMAGE_NAME="${ECR_BASE_NAME}/sqlserver_redhat"
  SQL_CLIENT_IMAGE_NAME="${ECR_BASE_NAME}/sqlserver_client_redhat"
  LIBERTY_BASE_IMAGE_NAME="${ECR_BASE_NAME}/liberty_redhat"
  LIBERTY_CONFIGURED_IMAGE_NAME="${ECR_BASE_NAME}/liberty_configured_redhat"
  ETL_CLIENT_IMAGE_NAME="${ECR_BASE_NAME}/etlclient_redhat"
  I2A_TOOLS_IMAGE_NAME="${ECR_BASE_NAME}/i2a_tools_redhat"
  LOAD_BALANCER_IMAGE_NAME="ha_proxy_image"
  CONNECTOR_IMAGE_NAME="example_connector"
else
  ZOOKEEPER_IMAGE_NAME="zookeeper_redhat"
  SOLR_IMAGE_NAME="solr_redhat"
  SQL_SERVER_IMAGE_NAME="sqlserver_redhat"
  SQL_CLIENT_IMAGE_NAME="sqlserver_client_redhat"
  LIBERTY_BASE_IMAGE_NAME="liberty_redhat"
  LIBERTY_CONFIGURED_IMAGE_NAME="liberty_configured_redhat"
  ETL_CLIENT_IMAGE_NAME="etlclient_redhat"
  I2A_TOOLS_IMAGE_NAME="i2a_tools_redhat"
  LOAD_BALANCER_IMAGE_NAME="ha_proxy_image"
  CONNECTOR_IMAGE_NAME="example_connector"
fi

###############################################################################
# Container names                                                             #
###############################################################################
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
SQL_SERVER_VOLUME_NAME="sqlvolume"
LIBERTY1_CONTAINER_NAME="liberty1"
LIBERTY2_CONTAINER_NAME="liberty2"
LOAD_BALANCER_CONTAINER_NAME="load_balancer"
CONNECTOR1_CONTAINER_NAME="exampleconnector1"
CONNECTOR2_CONTAINER_NAME="exampleconnector2"

###############################################################################
# Volume names                                                                #
###############################################################################
ZK1_DATA_VOLUME_NAME="${ZK1_CONTAINER_NAME}_data"
ZK1_DATALOG_VOLUME_NAME="${ZK1_CONTAINER_NAME}_datalog"
ZK1_LOG_VOLUME_NAME="${ZK1_CONTAINER_NAME}_logs"
ZK2_DATA_VOLUME_NAME="${ZK2_CONTAINER_NAME}_data"
ZK2_DATALOG_VOLUME_NAME="${ZK2_CONTAINER_NAME}_datalog"
ZK2_LOG_VOLUME_NAME="${ZK2_CONTAINER_NAME}_logs"
ZK3_DATA_VOLUME_NAME="${ZK3_CONTAINER_NAME}_data"
ZK3_DATALOG_VOLUME_NAME="${ZK3_CONTAINER_NAME}_datalog"
ZK3_LOG_VOLUME_NAME="${ZK3_CONTAINER_NAME}_logs"
SOLR1_VOLUME_NAME="${SOLR1_CONTAINER_NAME}_data"
SOLR2_VOLUME_NAME="${SOLR2_CONTAINER_NAME}_data"
SOLR3_VOLUME_NAME="${SOLR3_CONTAINER_NAME}_data"
LIBERTY1_VOLUME_NAME="${LIBERTY1_CONTAINER_NAME}_data"
LIBERTY2_VOLUME_NAME="${LIBERTY2_CONTAINER_NAME}_data"

###############################################################################
# User names                                                                  #
###############################################################################
SOLR_ADMIN_DIGEST_USERNAME="solr"
SOLR_APPLICATION_DIGEST_USERNAME="liberty"
ZK_DIGEST_USERNAME="solr"
ZK_DIGEST_READONLY_USERNAME="readonly-user"
SA_USERNAME="sa"
DBA_USERNAME="dba"
I2_ETL_USERNAME="i2etl"
ETL_USERNAME="etl"
I2_ANALYZE_USERNAME="i2analyze"
I2_GATEWAY_USERNAME="gateway.user"

###############################################################################
# Container secrets paths                                                     #
###############################################################################
CONTAINER_SECRETS_DIR="/run/secrets"
CONTAINER_CERTS_DIR="/tmp/i2acerts"

###############################################################################
# Security configuration                                                      #
###############################################################################
CA_DURATION="90"
CERTFICIATE_DURATION="90"
CERTIFICATE_KEY_SIZE=4096
CA_KEY_SIZE=4096
I2_ANALYZE_CERT_FOLDER_NAME="i2analyze"
GATEWAY_CERT_FOLDER_NAME="gateway_user"

###############################################################################
# Database variables                                                          #
###############################################################################
DB_DIALECT="sqlserver"
DB_NAME="ISTORE"
DB_PORT="1433"
DB_OS_TYPE="UNIX"
DB_INSTALL_DIR="/opt/mssql-tools"
DB_LOCATION_DIR="/var/opt/mssql/data"
SQLCMD="${DB_INSTALL_DIR}/bin/sqlcmd"
if [[ "$DB_SSL_CONNECTION" == true ]]; then
  SQLCMD_FLAGS="-N -b"
else
  SQLCMD_FLAGS="-b"
fi

###############################################################################
# Root Paths                                                                  #
###############################################################################
if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR=$(pwd)/../..
fi
PRE_REQS_DIR="${ROOT_DIR}/pre-reqs"
LOCAL_I2ANALYZE_DIR="${PRE_REQS_DIR}/i2analyze"
IMAGES_DIR="${ROOT_DIR}/images"
PRE_PROD_DIR="${ROOT_DIR}/environments/pre-prod"
LOCAL_CONFIG_DIR="${PRE_PROD_DIR}/configuration"
LOCAL_DATABASE_SCRIPTS_DIR="${PRE_PROD_DIR}/database-scripts"
LOCAL_GENERATED_DIR="${LOCAL_DATABASE_SCRIPTS_DIR}/generated"
LOCAL_TOOLKIT_DIR="${LOCAL_I2ANALYZE_DIR}/toolkit"
LOCAL_ETL_TOOLKIT_DIR="${IMAGES_DIR}/etl_client/etltoolkit"
LOCAL_EXAMPLE_CONNECTOR_APP_DIR="${IMAGES_DIR}/example_connector/app"

###############################################################################
# Configuration paths                                                         #
###############################################################################
LOCAL_CONFIG_COMMON_DIR="${LOCAL_CONFIG_DIR}/fragments/common/WEB-INF/classes"
LOCAL_CONFIG_OPAL_SERVICES_DIR="${LOCAL_CONFIG_DIR}/fragments/opal-services/WEB-INF/classes"
LOCAL_CONFIG_OPAL_SERVICES_IS_DIR="${LOCAL_CONFIG_DIR}/fragments/opal-services-is/WEB-INF/classes"
LOCAL_CONFIG_LIVE_DIR="${LOCAL_CONFIG_DIR}/live"
 
###############################################################################
# Security paths                                                              #
###############################################################################
GENERATED_SECRETS_DIR="${PRE_PROD_DIR}/generated-secrets"
LOCAL_CA_CERT_DIR="${GENERATED_SECRETS_DIR}/certificates/CA"
LOCAL_EXTERNAL_CA_CERT_DIR="${GENERATED_SECRETS_DIR}/certificates/externalCA"
LOCAL_KEYS_DIR="${PRE_PROD_DIR}/simulated-secret-store"

###############################################################################
# Walkthrough paths                                                           #
###############################################################################
LOCAL_CONFIG_CHANGES_DIR="${PRE_PROD_DIR}/walkthroughs/change-management/configuration-changes"

###############################################################################
# URIs                                                                        #
###############################################################################
BASE_URI="https://${I2_ANALYZE_FQDN}:${I2_ANALYZE_PORT}"
LOAD_BALANCER_STATS_URI="${BASE_URI}/haproxy_stats;csv"
FRONT_END_URI="${BASE_URI}/opal"
