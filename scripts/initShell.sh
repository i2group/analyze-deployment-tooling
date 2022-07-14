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

# Ensure NOT to add the following line in this script since it will be sourced to current terminal
# set -e

function printUsage() {
  echo "Usage:"
  echo "  initShell.sh [-y]"
  echo "  initShell.sh -h" 1>&2
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

function waitForUserReply() {
  local question="$1"
  echo "" # print an empty line

  if [[ "${YES_FLAG}" == "true" ]]; then
    echo "${question} (y/n) "
    echo "You selected -y flag, continuing"
    return 0
  fi

  while true; do
    read -r -p "${question} (y/n) " yn
    case $yn in
    [Yy]*) echo "" && break ;;
    [Nn]*) exit 1 ;;
    *) ;;
    esac
  done
}

function determineRootDir() {
  # Determine project root directory
  ANALYZE_CONTAINERS_ROOT_DIR=$(
    pushd . 1>/dev/null
    while [ "$(pwd)" != "/" ]; do
      test -e .root && grep -q 'Analyze-Containers-Root-Dir' <'.root' && {
        pwd
        break
      }
      cd ..
    done
    popd 1>/dev/null || exit
  )

  export ANALYZE_CONTAINERS_ROOT_DIR

  echo "New ANALYZE_CONTAINERS_ROOT_DIR root directory"
  echo "ANALYZE_CONTAINERS_ROOT_DIR=${ANALYZE_CONTAINERS_ROOT_DIR}"
}

if [[ -n "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  waitForUserReply "ANALYZE_CONTAINERS_ROOT_DIR is already set to ${ANALYZE_CONTAINERS_ROOT_DIR}. Are you sure you want to override it?"
fi

determineRootDir
