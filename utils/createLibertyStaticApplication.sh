#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
set -e

ENVIRONMENT="$1"
TARGET_DIR="$2"

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
checkEnvironmentIsValid
if [[ "${ENVIRONMENT}" == "pre-prod" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
elif [[ "${ENVIRONMENT}" == "config-dev" ]]; then
  source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
fi
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"

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

function populateLibertyApplication() {
  print "Populating static liberty application folder"
  cp -pr "$TOOLKIT_APPLICATION_DIR/targets/opal-services" "$TARGET_DIR"
  cp -pr "$TOOLKIT_APPLICATION_DIR/dependencies/icons" "$TARGET_DIR/opal-services"
  cp -pr "$TOOLKIT_APPLICATION_DIR/shared/lib" "$THIRD_PARTY_DIR/resources/i2-common"
  cp -pr "$TOOLKIT_APPLICATION_DIR/dependencies/tai" "$THIRD_PARTY_DIR/resources/security"
  cp -pr "$TOOLKIT_APPLICATION_DIR/server/." "$TARGET_DIR/"
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
# Create jvm.options file                                                     #
###############################################################################
createJvmOptions

###############################################################################
# Add config fragments used in development                                    #
###############################################################################
addDevConfigFragment

###############################################################################
# Make context root configurable                                              #
###############################################################################
addContextRootFragment

set +e
