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

echo "BASH_VERSION: $BASH_VERSION"
set -e

if [[ -z "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  echo "ANALYZE_CONTAINERS_ROOT_DIR variable is not set"
  echo "Please run '. initShell.sh' in your terminal first or set it with 'export ANALYZE_CONTAINERS_ROOT_DIR=<path_to_root>'"
  exit 1
fi

function printUsage() {
  echo "Usage:"
  echo "  createDevEnvironment.sh [-y]"
  echo "  createDevEnvironment.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -y                                     Answer 'yes' to all prompts." 1>&2
  echo "  -h                                     Display the help." 1>&2
  exit 1
}

while getopts ":yh" flag; do
  case "${flag}" in
  y)
    YES_FLAG="true"
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

# Load common functions
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/commonFunctions.sh"

# Load common variables
source "${ANALYZE_CONTAINERS_ROOT_DIR}/utils/simulatedExternalVariables.sh"

source "${ANALYZE_CONTAINERS_ROOT_DIR}/version"
warnRootDirNotInPath

print "Running createEnvironment.sh script"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createEnvironment.sh" -e "${ENVIRONMENT}"

print "Running createConfiguration.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/createConfiguration.sh" -e "${ENVIRONMENT}"

print "Running buildImages.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/buildImages.sh"

print "Running generateSecrets.sh"
"${ANALYZE_CONTAINERS_ROOT_DIR}/utils/generateSecrets.sh"
