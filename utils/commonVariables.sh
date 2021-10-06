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

# This file defines variables that are shared between all environments.
# It containes variables that may be changed by the end user,
# but aren't supposed to be changed unless there is a good reason for it.
# Examples:
# - image & container names
# - user names
# NOTE: this file has a dependency on the requiredEnvironmentVariables.txt

if [[ "$AWS_ARTEFACTS" == "true" ]]; then
  AWS_SECRETS="true"
  AWS_IMAGES="true"
  # aws cli [v2] - Default command output to a pager (https://github.com/aws/aws-cli/pull/4702)
  # Disable opening 'less' (default pager)
  export AWS_PAGER=""
  export AWS_DEFAULT_OUTPUT="json"
else 
  AWS_SECRETS="false"
  AWS_IMAGES="false"
fi

###############################################################################
# Image names                                                                 #
###############################################################################
if [[ "$AWS_IMAGES" == "true" ]]; then
  ZOOKEEPER_IMAGE_NAME="${ECR_BASE_NAME}/zookeeper_redhat"
  SOLR_IMAGE_NAME="${ECR_BASE_NAME}/solr_redhat"
  DB2_SERVER_IMAGE_NAME="${ECR_BASE_NAME}/db2_redhat"
  DB2_CLIENT_IMAGE_NAME="${ECR_BASE_NAME}/db2_client_redhat"
  SQL_SERVER_IMAGE_NAME="${ECR_BASE_NAME}/sqlserver_redhat"
  SQL_CLIENT_IMAGE_NAME="${ECR_BASE_NAME}/sqlserver_client_redhat"
  LIBERTY_BASE_IMAGE_NAME="${ECR_BASE_NAME}/liberty_redhat"
  LIBERTY_CONFIGURED_IMAGE_NAME="${ECR_BASE_NAME}/liberty_configured_redhat"
  ETL_CLIENT_IMAGE_NAME="${ECR_BASE_NAME}/etlclient_redhat"
  I2A_TOOLS_IMAGE_NAME="${ECR_BASE_NAME}/i2a_tools_redhat"
  LOAD_BALANCER_IMAGE_NAME="ha_proxy_image"
  CONNECTOR_IMAGE_NAME="${ECR_BASE_NAME}/example_connector"
  CONNECTOR_IMAGE_BASE_NAME="${ECR_BASE_NAME}/"
  I2CONNECT_SERVER_BASE_IMAGE_NAME="${ECR_BASE_NAME}/i2connect_sdk"
else
  ZOOKEEPER_IMAGE_NAME="zookeeper_redhat"
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
  I2CONNECT_SERVER_BASE_IMAGE_NAME="i2connect_sdk"
fi

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
else
  ETL_CLIENT_CONTAINER_NAME="etlclient.${CONFIG_NAME}"
  I2A_TOOL_CONTAINER_NAME="i2atool.${CONFIG_NAME}"
  ZK1_CONTAINER_NAME="zk1.${CONFIG_NAME}"
  ZK2_CONTAINER_NAME="zk2.${CONFIG_NAME}"
  ZK3_CONTAINER_NAME="zk3.${CONFIG_NAME}"
  SOLR_CLIENT_CONTAINER_NAME="solrClient.${CONFIG_NAME}"
  SOLR1_CONTAINER_NAME="solr1.${CONFIG_NAME}"
  SOLR2_CONTAINER_NAME="solr2.${CONFIG_NAME}"
  SOLR3_CONTAINER_NAME="solr3.${CONFIG_NAME}"
  SQL_CLIENT_CONTAINER_NAME="sqlclient.${CONFIG_NAME}"
  SQL_SERVER_CONTAINER_NAME="sqlserver.${CONFIG_NAME}"
  DB2_CLIENT_CONTAINER_NAME="db2client.${CONFIG_NAME}"
  DB2_SERVER_CONTAINER_NAME="db2server.${CONFIG_NAME}"
  LIBERTY1_CONTAINER_NAME="liberty1.${CONFIG_NAME}"
  LIBERTY2_CONTAINER_NAME="liberty2.${CONFIG_NAME}"
  LOAD_BALANCER_CONTAINER_NAME="load_balancer.${CONFIG_NAME}"
  CONNECTOR1_CONTAINER_NAME="exampleconnector1.${CONFIG_NAME}"
  CONNECTOR2_CONTAINER_NAME="exampleconnector2.${CONFIG_NAME}"
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
