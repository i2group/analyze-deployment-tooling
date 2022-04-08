#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
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
set -e

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Determine project root directory
ROOT_DIR=$(pushd . 1> /dev/null ; while [ "$(pwd)" != "/" ]; do test -e .root && grep -q 'Analyze-Containers-Root-Dir' < '.root' && { pwd; break; }; cd .. ; done ; popd 1> /dev/null)

ENVIRONMENT="$1"
TARGET_DIR="$2"

# Load common functions
source "${ROOT_DIR}/utils/commonFunctions.sh"
source "${ROOT_DIR}/utils/serverFunctions.sh"
source "${ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
checkEnvironmentIsValid
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ROOT_DIR}/utils/commonVariables.sh"
source "${ROOT_DIR}/utils/internalHelperVariables.sh"

TOOLKIT_APPLICATION_DIR="$LOCAL_TOOLKIT_DIR/application"
THIRD_PARTY_DIR="$TARGET_DIR/third-party-dependencies"

###############################################################################
# Function definitions                                                        #
###############################################################################
function addDevConfigFragment() {
  sed -i 's/<include location="server.extensions.xml"\/>/<include location="server.extensions.xml"\/>\n  <include location="server.extensions.dev.xml"\/>/' "$TARGET_DIR/server-config/server.xml"
}

function addContextRootFragment() {
  # We want this to output ${CONTEXT_ROOT} without expansion
  # shellcheck disable=SC2016
  sed -i 's/<application context-root="opal"/<variable name="CONTEXT_ROOT" defaultValue="opal" \/>\n  <application context-root="${CONTEXT_ROOT}"/' "$TARGET_DIR/server-config/server.xml"
}

function updateDatasourcesFile() {
  # This is a workaround needs fixing with the next release
  printInfo "Updating mssql server version"
  sed -i "s/mssql-jdbc-7.4.1/mssql-jdbc-7.*/" "$TARGET_DIR/server.datasources.sqlserver.xml"
}

function populateLibertyApplication() {
  print "Populating static liberty application folder"
  cp -pr "$TOOLKIT_APPLICATION_DIR/targets/opal-services" "$TARGET_DIR"
  cp -pr "$TOOLKIT_APPLICATION_DIR/dependencies/icons" "$TARGET_DIR/opal-services"
  cp -pr "$TOOLKIT_APPLICATION_DIR/shared/lib" "$THIRD_PARTY_DIR/resources/i2-common"
  cp -pr "$TOOLKIT_APPLICATION_DIR/dependencies/tai" "$THIRD_PARTY_DIR/resources/security"
  cp -pr "$TOOLKIT_APPLICATION_DIR/server/." "$TARGET_DIR/"
  updateDatasourcesFile
}

function remediateLog4jVulnerability() {
  # Remediate log4j vulnerability
  # CVE-2021-44228
  # TODO Improve - minior version changes?
  local LOG4J_VER="2.17.2"
  local LOG4J_BIN="apache-log4j-${LOG4J_VER}-bin.tar.gz"
  local LOG4J_BASE_URL="https://dlcdn.apache.org/logging"
  local LOG4J_ARCHIVE_URL="${LOG4J_BASE_URL}/log4j/${LOG4J_VER}/${LOG4J_BIN}"
  local LOG4J_SHA512="cb3c349ae03b94ee9f066c8a1eaf9810a5cd56b9357180e5ff9c13d66c2aceea8b9095650ac4304dbcccea6c1280f255e940fde23045b6598896b655594bd75f"
  local I2_COMMON_DIR="$THIRD_PARTY_DIR/resources/i2-common/lib"
  local TMP_LOG4J_FOLDER="/tmp/log4j"

  mkdir -p "${TMP_LOG4J_FOLDER}"
  echo "Downloading ${LOG4J_ARCHIVE_URL}"
  if curl --retry 10 --max-redirs 1 -o "${TMP_LOG4J_FOLDER}/${LOG4J_BIN}" "${LOG4J_ARCHIVE_URL}"; then echo "Download Succesfull"; else rm -f "${TMP_LOG4J_FOLDER}/${LOG4J_BIN}"; fi
  if [ ! -f "${TMP_LOG4J_FOLDER}/${LOG4J_BIN}" ]; then
    echo "Failed all download attempts for ${LOG4J_BIN}"
    exit 1
  fi
  echo "Verifing SHA512 signature on the files"
  echo "$LOG4J_SHA512 *${TMP_LOG4J_FOLDER}/${LOG4J_BIN}" | sha512sum -c -

  tar -C "${TMP_LOG4J_FOLDER}" --extract --file "${TMP_LOG4J_FOLDER}/${LOG4J_BIN}"

  rm -f "${I2_COMMON_DIR}"/log4j-core-*.jar \
    "${I2_COMMON_DIR}"/log4j-1.2-api-*.jar \
    "${I2_COMMON_DIR}"/log4j-api-*.jar \
    "${I2_COMMON_DIR}"/log4j-slf4j-impl-*.jar

  cp "${TMP_LOG4J_FOLDER}/apache-log4j-${LOG4J_VER}-bin/log4j-core-${LOG4J_VER}.jar" \
    "${TMP_LOG4J_FOLDER}/apache-log4j-${LOG4J_VER}-bin/log4j-1.2-api-${LOG4J_VER}.jar" \
    "${TMP_LOG4J_FOLDER}/apache-log4j-${LOG4J_VER}-bin/log4j-api-${LOG4J_VER}.jar" \
    "${TMP_LOG4J_FOLDER}/apache-log4j-${LOG4J_VER}-bin/log4j-slf4j-impl-${LOG4J_VER}.jar" \
    "${I2_COMMON_DIR}"

  rm -rf "${TMP_LOG4J_FOLDER}"
  # end log4j remediation
}

function createJvmOptions() {
  # This should be removed when we move to Groovy 3.x
  print "Creating jvm.options file"
  {
    echo ""
    echo "--add-opens=java.base/java.nio=ALL-UNNAMED"
    echo "--add-opens=java.base/java.io=ALL-UNNAMED"
    echo "--add-opens=java.base/java.lang=ALL-UNNAMED"
    echo "--add-opens=java.base/java.lang.reflect=ALL-UNNAMED"
    echo "--add-opens=java.base/java.net=ALL-UNNAMED"
    echo "--add-opens=java.base/java.nio.file=ALL-UNNAMED"
    echo "--add-opens=java.base/java.security=ALL-UNNAMED"
    echo "--add-opens=java.base/java.text=ALL-UNNAMED"
    echo "--add-opens=java.base/java.util=ALL-UNNAMED"
    echo "--add-opens=java.base/java.util.regex=ALL-UNNAMED"
    echo "--add-opens=java.base/java.util.stream=ALL-UNNAMED"
    echo "--add-opens=java.base/sun.nio.fs=ALL-UNNAMED"
    echo "--add-opens=java.xml/com.sun.org.apache.xerces.internal.jaxp.validation=ALL-UNNAMED"
    echo "--add-opens=java.xml/com.sun.org.apache.xerces.internal.xs=ALL-UNNAMED"
    echo "--add-opens=java.xml/javax.xml=ALL-UNNAMED"
    echo "--add-opens=java.xml/javax.xml.transform.stream=ALL-UNNAMED"
    echo "--add-opens=java.xml/javax.xml.validation=ALL-UNNAMED"
  } >>"${TARGET_DIR}/jvm.options"
}

###############################################################################
# Create required directories                                                 #
###############################################################################
mkdir -p "$TARGET_DIR"
mkdir -p "$THIRD_PARTY_DIR/resources"
mkdir -p "$THIRD_PARTY_DIR/resources/i2-common"
mkdir -p "$THIRD_PARTY_DIR/resources/security"
mkdir -p "$THIRD_PARTY_DIR/resources/jdbc"

###############################################################################
# Populate liberty application                                                #
###############################################################################
populateLibertyApplication

###############################################################################
# Remediate log4j Vulnerability                                               #
###############################################################################
remediateLog4jVulnerability

###############################################################################
# Create jvm.options file                                                     #
###############################################################################
createJvmOptions

###############################################################################
# Add config framents used in development                                     #
###############################################################################
addDevConfigFragment

###############################################################################
# Make context root configurable                                              #
###############################################################################
addContextRootFragment

set +e
