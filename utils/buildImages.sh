#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

function printUsage() {
  echo "Usage:"
  echo "    buildImages.sh" 1>&2
  echo "    buildImages.sh [-e {pre-prod|config-dev}]" 1>&2
  echo "    buildImages.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:"
  echo "    -e {pre-prod}   Used to generate images for pre-prod example." 1>&2
  echo "    -e {config-dev} Used to generate images for configuration development." 1>&2
  echo "    -v              Verbose output." 1>&2
  echo "    -h              Display the help." 1>&2
  exit 1
}

while getopts ":e:vh" flag; do
  case "${flag}" in
  e)
    ENVIRONMENT="${OPTARG}"
    ;;
  v)
    VERBOSE="true"
    ;;
  h)
    help
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

if [[ -z "${ENVIRONMENT}" ]]; then
  ENVIRONMENT="config-dev"
fi

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

###############################################################################
# Pull latest supported base images                                           #
###############################################################################
print "Pull base images"
docker pull registry.access.redhat.com/ubi8/ubi-minimal:8.6
docker pull haproxy:2.2
docker pull "i2group/i2eng-liberty:${LIBERTY_VERSION}"
docker pull "i2group/i2eng-solr:${SOLR_VERSION}"
docker pull "i2group/i2eng-zookeeper:${ZOOKEEPER_VERSION}"
docker pull "i2group/i2eng-prometheus:${PROMETHEUS_VERSION}"
docker pull "grafana/grafana-oss:${GRAFANA_VERSION}"
docker pull mcr.microsoft.com/mssql/rhel/server:2019-CU11-rhel-8.3

###############################################################################
# Building load balancer image                                                #
###############################################################################
print "Building load balancer image"
docker build -t "${LOAD_BALANCER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/ha_proxy"

###############################################################################
# Building Liberty base image                                                 #
###############################################################################
toolkit_version=$(cat "${LOCAL_TOOLKIT_DIR}/scripts/version.txt")
print "Building Liberty base image"
docker build -t "${LIBERTY_BASE_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/liberty_ubi_base" \
  --build-arg I2ANALYZE_VERSION="${toolkit_version%%-*}"

###############################################################################
# Building Solr image                                                         #
###############################################################################
print "Building Solr image"
docker build -t "${SOLR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/solr_redhat" \
  --build-arg I2ANALYZE_VERSION="${toolkit_version%%-*}"

###############################################################################
# Building Db2 Server image                                                   #
###############################################################################
# print "Building Db2 Server image"
# docker build -t "${DB2_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/db2_server"

###############################################################################
# Building Db2 Client image                                                   #
###############################################################################
# print "Building Db2 Client image"
# docker build -t "${DB2_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/db2_client"

###############################################################################
# Building SQL Server image                                                   #
###############################################################################
print "Building SQL Server image"
docker build -t "${SQL_SERVER_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/sql_server"

###############################################################################
# Building SQL Client image                                                   #
###############################################################################
print "Building SQL Client image"
docker build -t "${SQL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/sql_client"

###############################################################################
# Building i2 Analyze Tool image                                              #
###############################################################################
print "Building i2 Analyze Tool image"
docker image build -t "${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/i2a_tools" \
  --build-arg USER_UID="$(id -u "${USER}")" \
  --build-arg I2ANALYZE_VERSION="${toolkit_version%%-*}"

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
cp "${LOCAL_CONFIG_I2_TOOLS_DIR}/"* "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_ISTORE_NAMES_SQL_SERVER_PROPERTIES_FILE}" "${IMAGES_DIR}/etl_client/etltoolkit/classes"
cp "${LOCAL_ISTORE_NAMES_DB2_PROPERTIES_FILE}" "${IMAGES_DIR}/etl_client/etltoolkit/classes"
docker build -t "${ETL_CLIENT_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/etl_client" \
  --build-arg BASE_IMAGE="${I2A_TOOLS_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}"

###############################################################################
# Building Example connector image                                            #
###############################################################################
docker build -t "${CONNECTOR_IMAGE_NAME}:${I2A_DEPENDENCIES_IMAGES_TAG}" "${IMAGES_DIR}/example_connector"
