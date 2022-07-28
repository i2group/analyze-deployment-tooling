#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "This project should be run inside a VSCode Dev Container. For more information read, the Getting Started guide at https://i2group.github.io/analyze-containers/content/getting_started.html"
  exit 1
fi

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/examples/pre-prod/utils/simulatedExternalVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"

createLicenseConfiguration

print "Running createEnvironment.sh script"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createEnvironment.sh" -e "${ENVIRONMENT}"

print "Running createConfiguration.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createConfiguration.sh" -e "${ENVIRONMENT}"

setDependenciesTagIfNecessary

print "Running buildImages.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildImages.sh" -e "${ENVIRONMENT}"

print "Running generateSecrets.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/generateSecrets.sh"

echo "Success: Pre-prod environment created"
