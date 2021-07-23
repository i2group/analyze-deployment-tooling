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

set -e
DEFAULT_SERVER_DIR=/opt/ibm/wlp/usr/servers/defaultServer

function createConnectorConfig() {
  connectors_template_file=${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes/connectors-template.json
  connectors_file=${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes/connectors.json
  temp_file=${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes/temp.json
  allready_run=${DEFAULT_SERVER_DIR}/apps/opal-services.war/allready_run
  
  if [[ -f ${allready_run} ]]; then
    return
  fi

  #Create connectors.json
  if [[ -n ${CONNECTOR_URL_MAP} && ! -f "${connectors_template_file}" ]]; then
    echo "CONNECTOR_URL_MAP found but connectors-template.json is missing"
    exit 1
  fi

  if [[ -z ${CONNECTOR_URL_MAP} && ! -f "${connectors_file}" ]]; then
    echo "CONNECTOR_URL_MAP not found and connectors.json is missing"
    exit 1
  fi

  if [[ -z ${CONNECTOR_URL_MAP} ]]; then
    #Nothing to do
    return
  fi

  if [[ -f "${connectors_file}" ]]; then
    echo "CONNECTOR_URL_MAP specified but connectors.json also found. Exiting"
    exit 1
  fi

  #Read the connector_url_map into an associative array
  declare -A connector_url_map
  while read -r key value; do
    connector_url_map[$key]="$value"
  done < <(jq -r 'map(.id + " " + .baseUrl)|.[]' < <(echo "${CONNECTOR_URL_MAP}"))

  #Find all connector ids from template
  readarray -t ids < <(jq -r '.connectors[].id' <"${connectors_template_file}")

  #Copy the template to the connectors file
  cp $connectors_template_file $connectors_file
  #Iterate over connectors and use mapping to update file each time
  for connector_id in "${ids[@]}"; do
    baseUrl="${connector_url_map[$connector_id]}"
    if [[ -z ${baseUrl} ]]; then
      echo "The CONNECTOR_URL_MAP does not contain an entry for: ${connector_id}"
      exit 1
    fi
    jq -r --arg connector_id "${connector_id}" \
      --arg baseUrl "${baseUrl}" \
      '.connectors | map(select(.id==$connector_id) + {baseUrl: $baseUrl} + {configUrl: .configurationPath}, select(.id!=$connector_id)) | map(del(select(.id==$connector_id)| .configurationPath )) | {connectors: map(.) }' \
      <"${connectors_file}" >"${temp_file}"
    mv "${temp_file}" "${connectors_file}"
  done
  touch "${allready_run}"
}

createConnectorConfig