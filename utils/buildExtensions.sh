#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

set -e

function printUsage() {
  echo "Usage:"
  echo "  buildExtensions.sh -c <config_name> [-y] [-v]" 1>&2
  echo "  buildExtensions.sh -c <config_name> [-i <extension1_name>] [-e <extension1_name>] [-y] [-v]" 1>&2
  echo "  buildExtensions.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:"
  echo "  -c <config_name>      Name of the config to use." 1>&2
  echo "  -i <extension_name>   Names of the extensions to deploy and update. To specify multiple extensions, add additional -i options." 1>&2
  echo "  -e <extension_name>   Names of the extensions to deploy and udapte. To specify multiple extensions, add additional -e options." 1>&2
  echo "  -v                    Verbose output." 1>&2
  echo "  -y                    Answer 'yes' to all prompts." 1>&2
  echo "  -h                    Display the help." 1>&2
  exit 1
}

while getopts ":c:i:e:hvy" flag; do
  case "${flag}" in
  c)
    CONFIG_NAME="${OPTARG}"
    ;;
  i)
    INCLUDED_EXTENSIONS+=("$OPTARG")
    ;;
  e)
    EXCLUDED_EXTENSIONS+=("${OPTARG}")
    ;;
  y)
    YES_FLAG="true"
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

if [[ "${INCLUDED_EXTENSIONS[*]}" && "${EXCLUDED_EXTENSIONS[*]}" ]]; then
  printf "\e[31mERROR: Incompatible options: Both (-i) and (-e) were specified.\n" >&2
  printf "\e[0m" >&2
  usage
  exit 1
fi

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/serverFunctions.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/clientFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/internalHelperVariables.sh"
source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"

function installJarToMavenLocalIfNecessary() {
  local group_id="${1}"
  local artifact_id="${2}"
  local version="${3}"
  local file_path="${4}"

  if ! mvn dependency:get -Dartifact="${group_id}:${artifact_id}:${version}" >/dev/null; then
    mvn install:install-file -Dfile="${file_path}" -DgroupId="${group_id}" -DartifactId="${artifact_id}" -Dversion="${version}" -Dpackaging=jar
  fi
}

function removeJarFromMavenLocal() {
  local group_id="${1}"
  local artifact_id="${2}"

  mvn dependency:purge-local-repository -DmanualInclude="${group_id}:${artifact_id}"
}

function setupI2AnalyzeMavenLocal() {
  local libPath="${TOOLKIT_APPLICATION_DIR}/targets/opal-services/WEB-INF/lib"
  local sharedPath="${TOOLKIT_APPLICATION_DIR}/shared/lib"

  print "Ensure i2Analyze dependencies are installed..."

  installJarToMavenLocalIfNecessary "com.i2group" "apollo-legacy" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/ApolloLegacy.jar"
  installJarToMavenLocalIfNecessary "com.i2group" "disco-api" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/disco-api-9.2.jar"
  installJarToMavenLocalIfNecessary "com.i2group" "daod" "${SUPPORTED_I2ANALYZE_VERSION}" "${libPath}/Daod.jar"
  installJarToMavenLocalIfNecessary "com.i2group" "disco-utils" "${SUPPORTED_I2ANALYZE_VERSION}" "${sharedPath}/DiscoUtils.jar"

  pushd "${EXTENSIONS_DIR}" >/dev/null
  mvn install
  popd >/dev/null
}

function isRebuildRequired() {
  local artifact_id="$1"
  local artifact_dir="${EXTENSIONS_DIR}/${artifact_id}"

  current_checksum=$(getChecksumOfDir "${artifact_dir}" "*/target/*")
  if [[ -f "${PREVIOUS_EXTENSIONS_DIR}/${artifact_id}.sha512" ]]; then
    previous_checksum=$(cat "${PREVIOUS_EXTENSIONS_DIR}/${artifact_id}.sha512")
    if [[ "${previous_checksum}" == "${current_checksum}" ]]; then
      echo "false"
      return
    fi
  fi
  echo "true"
}

function buildExtension() {
  local artifact_id="$1"
  local artifact_dir="${EXTENSIONS_DIR}/${artifact_id}"
  local extension_dependencies_path="${EXTENSIONS_DIR}/extension-dependencies.json"
  local dependencies
  local rebuild_dependencies="false"
  local rebuild_extension="false"

  createFolder "${PREVIOUS_EXTENSIONS_DIR}"

  if [[ ! -d "${artifact_dir}" ]]; then
    printErrorAndExit "Artifact ${artifact_id} does NOT exist"
  fi

  IFS=' ' read -ra dependencies <<<"$(jq -r --arg name "${artifact_id}" '.[] | select(.name == $name) | .dependencies[]' "${extension_dependencies_path}" | xargs)"

  for dependency in "${dependencies[@]}"; do
    rebuild_dependencies=$(isRebuildRequired "${dependency}")
    if [[ "${rebuild_dependencies}" == "true" ]]; then
      buildExtension "${dependency}"
    fi
  done

  rebuild_extension=$(isRebuildRequired "${artifact_id}")
  if [[ "${rebuild_extension}" == "true" || "${rebuild_dependencies}" == "true" ]]; then
    buildExtensionJar "${artifact_dir}"
    current_checksum=$(getChecksumOfDir "${artifact_dir}" "*/target/*")
    echo "${current_checksum}" >"${PREVIOUS_EXTENSIONS_DIR}/${artifact_id}.sha512"
  fi
}

function buildExtensionJar() {
  local artifact_dir="$1"

  print "Creating Extension: ${artifact_id}"
  cd "${artifact_dir}"
  mvn install -Doutput.dir="${artifact_dir}/target" -Di2analyze.root.dir="${ANALYZE_CONTAINERS_ROOT_DIR}"
}

function cleanArtifacts() {
  print "Cleaning all deployed artifacts"
  waitForUserReply "Are you sure you want to run the 'clean' task? This will permanently remove data from the deployment."

  removeJarFromMavenLocal "com.i2group" "apollo-legacy"
  removeJarFromMavenLocal "com.i2group" "disco-api"
  removeJarFromMavenLocal "com.i2group" "daod"
  removeJarFromMavenLocal "com.i2group" "disco-utils"
}

###############################################################################
# Set up environment                                                          #
###############################################################################
setupI2AnalyzeMavenLocal

###############################################################################
# Build extensions                                                            #
###############################################################################
setListOfExtensionsToUpdate
for extension_name in "${EXTENSION_NAMES[@]}"; do
  buildExtension "${extension_name}"
done
