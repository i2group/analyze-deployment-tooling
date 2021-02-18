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
cd "$SCRIPT_DIR"

# Load common functions and variables
source ./utils/commonFunctions.sh
source ./utils/commonVariables.sh
source ./utils/clientFunctions.sh

JAVA_CONTAINER_VOLUME_DIR="/simulatedKeyStore"

###############################################################################
# Functions                                                                   #
###############################################################################
function runJava() {
  docker run \
    --rm \
    --name "${I2A_TOOL_CONTAINER_NAME}" \
    --user "$(id -u "${USER}"):$(id -u "${USER}")" \
    -v "${GENERATED_SECRETS_DIR}/certificates:/simulatedKeyStore" \
    "${I2A_TOOLS_IMAGE_NAME}" "$@"
}

function securelyDeleteFolderIfExistsAndCreate() {
  local FOLDER=${1}

  if [[ -d "${FOLDER}" ]]; then
    find "${FOLDER}" -type f -exec shred -u {} \;
    rm -rf "${FOLDER}"
  fi
  mkdir -p "${FOLDER}"
}

function createCA() {
  local CONTEXT=${1}
  local CA_CER=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}/CA.cer
  local CA_KEY=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}/CA.key
  local TMP=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}/.csr
  local EXT=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}/x509.ext

  print "Creating Certificate Authority"

  securelyDeleteFolderIfExistsAndCreate "${GENERATED_SECRETS_DIR}/certificates/${CONTEXT}"
  cp -p ./utils/templates/x509.ext.template "${GENERATED_SECRETS_DIR}/certificates/${CONTEXT}/x509.ext.template"
  cp "${GENERATED_SECRETS_DIR}/certificates/${CONTEXT}/x509.ext.template" "${GENERATED_SECRETS_DIR}/certificates/${CONTEXT}/x509.ext"

  # Generate CA.key
  runJava openssl req -new -nodes -newkey rsa:"${CA_KEY_SIZE}" -keyout "${CA_KEY}" -subj "/CN=i2Analyze-eia" -out "${TMP}"
  # Generate CA.cer
  runJava openssl x509 -req -sha256 -extfile "${EXT}" -extensions ca -in "${TMP}" -signkey "${CA_KEY}" -days "${CA_DURATION}" -out "${CA_CER}"
  # Clean up
  runJava chmod a+r "${CA_CER}" && runJava rm "${TMP}" "${EXT}"
}

function createCertificates() {
  local CONTAINER=${1}
  local FQDN=${2}
  local TYPE=${3}
  local CONTEXT=${4}
  local KEY=${JAVA_CONTAINER_VOLUME_DIR}/${CONTAINER}/server.key
  local CER=${JAVA_CONTAINER_VOLUME_DIR}/${CONTAINER}/server.cer
  local TMP=${JAVA_CONTAINER_VOLUME_DIR}/${CONTAINER}-key.csr
  local CA_CER=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}CA/CA.cer
  local CA_KEY=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}CA/CA.key
  local CA_SRL=${JAVA_CONTAINER_VOLUME_DIR}/CA.srl
  local EXT=${JAVA_CONTAINER_VOLUME_DIR}/${CONTEXT}CA/x509.ext

  print "Create Raw Certificates"
  securelyDeleteFolderIfExistsAndCreate "${GENERATED_SECRETS_DIR}/certificates/${CONTAINER}"

  if [[ "${CONTEXT}" == external ]]; then
    sed "s/HOST_NAME/${FQDN}/" "${LOCAL_EXTERNAL_CA_CERT_DIR}/x509.ext.template" >"${LOCAL_EXTERNAL_CA_CERT_DIR}/x509.ext"
  else
    sed "s/HOST_NAME/${FQDN}/" "${LOCAL_CA_CERT_DIR}/x509.ext.template" >"${LOCAL_CA_CERT_DIR}/x509.ext"
  fi

  # Generate key
  runJava openssl genrsa -out "${KEY}" "${CERTIFICATE_KEY_SIZE}"
  # Generate certificate signing request
  runJava openssl req -new -key "${KEY}" -subj "/CN=${FQDN}" -out "${TMP}"
  # Generate certificate
  runJava openssl x509 -req -sha256 -CA "${CA_CER}" -CAkey "${CA_KEY}" -days "${CERTFICIATE_DURATION}" -CAcreateserial -CAserial "${CA_SRL}" -extfile "${EXT}" -extensions "${TYPE}" -in "${TMP}" -out "${CER}"
  # Clean up
  runJava chmod a+r "${KEY}" "${CER}" && runJava rm "${TMP}" "${CA_SRL}" "${EXT}"
}

function createSSLCertificates() {
  print "Creating SSL certificates"
  createCertificates "${ZK1_CONTAINER_NAME}" "${ZK1_FQDN}" zk
  createCertificates "${ZK2_CONTAINER_NAME}" "${ZK2_FQDN}" zk
  createCertificates "${ZK3_CONTAINER_NAME}" "${ZK3_FQDN}" zk
  createCertificates "${SOLR1_CONTAINER_NAME}" "${SOLR1_FQDN}" solr
  createCertificates "${SOLR2_CONTAINER_NAME}" "${SOLR2_FQDN}" solr
  createCertificates "${SOLR3_CONTAINER_NAME}" "${SOLR3_FQDN}" solr
  createCertificates "${SOLR_CLIENT_CONTAINER_NAME}" "${SOLR_CLIENT_FQDN}" solr
  createCertificates "${I2A_TOOL_CONTAINER_NAME}" "${I2A_TOOL_FQDN}" solr
  createCertificates "${LIBERTY1_CONTAINER_NAME}" "${LIBERTY1_FQDN}" liberty
  createCertificates "${LIBERTY2_CONTAINER_NAME}" "${LIBERTY2_FQDN}" liberty
  createCertificates "${SQL_SERVER_CONTAINER_NAME}" "${SQL_SERVER_FQDN}" sqlserver
  createCertificates "${CONNECTOR1_CONTAINER_NAME}" "${CONNECTOR1_FQDN}" connector
  createCertificates "${CONNECTOR2_CONTAINER_NAME}" "${CONNECTOR2_FQDN}" connector
  createCertificates "${GATEWAY_CERT_FOLDER_NAME}" "${I2_GATEWAY_USERNAME}" liberty
  createCertificates "${I2_ANALYZE_CERT_FOLDER_NAME}" "${I2_ANALYZE_FQDN}" liberty external
}

function generateRandomPassword() {
  local PASSWORD_FILE_LOCATION=${1}

  if [[ -f "${PASSWORD_FILE_LOCATION}" ]]; then
    shred -u "${PASSWORD_FILE_LOCATION}"
  fi

  touch "${PASSWORD_FILE_LOCATION}"
  cat >"${PASSWORD_FILE_LOCATION}" <<<"$(runJava openssl rand -base64 16)"
}

function generateSolrPasswords() {
  securelyDeleteFolderIfExistsAndCreate "${GENERATED_SECRETS_DIR}/solr"

  print "Generating Solr Passwords"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/solr/SOLR_APPLICATION_DIGEST_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/solr/SOLR_ADMIN_DIGEST_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_READONLY_PASSWORD"
}

function generateSqlserverPasswords() {
  securelyDeleteFolderIfExistsAndCreate "${GENERATED_SECRETS_DIR}/sqlserver"

  print "Generating Sqlserver Passwords"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/dbb_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/i2analyze_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/i2etl_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/etl_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/dba_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/sa_PASSWORD"
  generateRandomPassword "${GENERATED_SECRETS_DIR}/sqlserver/sa_INITIAL_PASSWORD"
}

function generateSolrSecurityJson() {
  local SOLR_ADMIN_SALT
  local SOLR_ADMIN_DIGEST
  local SOLR_APPLICATION_SALT
  local SOLR_APPLICATION_DIGEST

  print "Generating Solr security.json file"

  # Generate a random salt
  SOLR_ADMIN_SALT=$(openssl rand -base64 32)

  # Create the solr digest
  SOLR_ADMIN_DIGEST=$( (
    echo -n "${SOLR_ADMIN_SALT}" | base64 -d
    echo -n "$(cat "${GENERATED_SECRETS_DIR}/solr/SOLR_ADMIN_DIGEST_PASSWORD")"
  ) | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | base64)

  # Generate a random salt
  SOLR_APPLICATION_SALT=$(openssl rand -base64 32)

  # Create the solr digest
  SOLR_APPLICATION_DIGEST=$( (
    echo -n "${SOLR_APPLICATION_SALT}" | base64 -d
    echo -n "$(cat "${GENERATED_SECRETS_DIR}/solr/SOLR_APPLICATION_DIGEST_PASSWORD")"
  ) | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | base64)

  # Create the security.json file
  cat <"./utils/templates/security-template.json" | jq '.authentication.credentials +=
  {
    "liberty":"'"${SOLR_APPLICATION_DIGEST} ${SOLR_APPLICATION_SALT}"'",
    "solr": "'"${SOLR_ADMIN_DIGEST} ${SOLR_ADMIN_SALT}"'"
  }' >"${GENERATED_SECRETS_DIR}/solr/security.json"
}

function simulateContainerSecretStoreAccess() {
  local CONTEXT="${1}"
  local TYPE="${2}"
  print "Simulating Secret Store Access: ${CONTEXT}"

  securelyDeleteFolderIfExistsAndCreate "${LOCAL_KEYS_DIR}/${CONTEXT}"
  cp -pr "${GENERATED_SECRETS_DIR}/certificates/${CONTEXT}/." "${LOCAL_KEYS_DIR}/${CONTEXT}/"
  cp "${GENERATED_SECRETS_DIR}/certificates/${TYPE}CA/CA.cer" "${LOCAL_KEYS_DIR}/${CONTEXT}/CA.cer"
}

function simulateLibertySecretStoreAccess() {
  local CONTAINER="${1}"

  simulateContainerSecretStoreAccess "${CONTAINER}"
  cp "${GENERATED_SECRETS_DIR}/sqlserver/i2analyze_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/DB_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/solr/SOLR_APPLICATION_DIGEST_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/SOLR_APPLICATION_DIGEST_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/ZK_DIGEST_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/certificates/gateway_user/server.cer" "${LOCAL_KEYS_DIR}/${CONTAINER}/gateway_user.cer"
  cp "${GENERATED_SECRETS_DIR}/certificates/gateway_user/server.key" "${LOCAL_KEYS_DIR}/${CONTAINER}/gateway_user.key"
}

function simulateSolrSecretStoreAccess() {
  local CONTAINER="${1}"

  simulateContainerSecretStoreAccess "${CONTAINER}"
  cp "${GENERATED_SECRETS_DIR}/solr/SOLR_ADMIN_DIGEST_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/SOLR_ADMIN_DIGEST_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/ZK_DIGEST_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_READONLY_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/ZK_DIGEST_READONLY_PASSWORD"
}

function simulateZkSecretStoreAccess() {
  local CONTAINER="${1}"

  simulateContainerSecretStoreAccess "${CONTAINER}"
  cp "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/ZK_DIGEST_PASSWORD"
  cp "${GENERATED_SECRETS_DIR}/solr/ZK_DIGEST_READONLY_PASSWORD" "${LOCAL_KEYS_DIR}/${CONTAINER}/ZK_DIGEST_READONLY_PASSWORD"
}

function simulateSqlserverSecretStoreAccess() {
  local CONTAINER="${1}"

  simulateContainerSecretStoreAccess "${CONTAINER}"
  cp "${GENERATED_SECRETS_DIR}/sqlserver/sa_INITIAL_PASSWORD" "${LOCAL_KEYS_DIR}/sqlserver/SA_PASSWORD"
}

function simulateServerSecretStoreAccess() {
  securelyDeleteFolderIfExistsAndCreate "${LOCAL_KEYS_DIR}"
  simulateLibertySecretStoreAccess "${LIBERTY1_CONTAINER_NAME}"
  simulateLibertySecretStoreAccess "${LIBERTY2_CONTAINER_NAME}"
  simulateZkSecretStoreAccess "${ZK1_CONTAINER_NAME}"
  simulateZkSecretStoreAccess "${ZK2_CONTAINER_NAME}"
  simulateZkSecretStoreAccess "${ZK3_CONTAINER_NAME}"
  simulateContainerSecretStoreAccess "${CONNECTOR1_CONTAINER_NAME}"
  simulateContainerSecretStoreAccess "${CONNECTOR2_CONTAINER_NAME}"
  simulateSolrSecretStoreAccess "${SOLR1_CONTAINER_NAME}"
  simulateSolrSecretStoreAccess "${SOLR2_CONTAINER_NAME}"
  simulateSolrSecretStoreAccess "${SOLR3_CONTAINER_NAME}"
  simulateSqlserverSecretStoreAccess "${SQL_SERVER_CONTAINER_NAME}"
  simulateContainerSecretStoreAccess "${I2_ANALYZE_CERT_FOLDER_NAME}" external
}

###############################################################################
# Create self signed CA                                                      #
###############################################################################
createCA "CA"
createCA "externalCA"

###############################################################################
# Setting up SSL certificates                                                 #
###############################################################################
createSSLCertificates

###############################################################################
# Generate Passwords                                                          #
###############################################################################
generateSolrPasswords
generateSqlserverPasswords

###############################################################################
# Create security.json file for solr                                          #
###############################################################################
generateSolrSecurityJson

###############################################################################
# Simulate Secret store access                                                #
###############################################################################
simulateServerSecretStoreAccess

# Commented out function to remove generated secrets folder
# securelyDeleteFolderIfExistsAndCreate "${GENERATED_SECRETS_DIR}"
