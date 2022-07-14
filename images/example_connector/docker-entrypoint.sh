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

. /opt/environment.sh

if [[ ${SSL_ENABLED} == true ]]; then
	file_env 'SSL_CA_CERTIFICATE'
	file_env 'SSL_CERTIFICATE'
	file_env 'SSL_PRIVATE_KEY'
	if [[ -z ${SSL_CA_CERTIFICATE} || -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} ]]; then
		echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
		exit 1
	fi

	TMP_SECRETS=/tmp/i2acerts
	CA_CER=${TMP_SECRETS}/CA.cer
	SERVER_KEY=${TMP_SECRETS}/server.key
	SERVER_CER=${TMP_SECRETS}/server.cer

	if [[ -d ${TMP_SECRETS} ]]; then
		rm -r ${TMP_SECRETS}
	fi
	mkdir ${TMP_SECRETS}

	echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
	echo "${SSL_PRIVATE_KEY}" >"${SERVER_KEY}"
	echo "${SSL_CERTIFICATE}" >"${SERVER_CER}"
fi

echo '{
  "https": '"${SSL_ENABLED}"',
  "keyFileName": "'"${SERVER_KEY}"'",
  "keyPassphrase": "",
  "certificateFileName": "'"${SERVER_CER}"'",
  "certificateAuthorityFileName": "'"${CA_CER}"'",
  "gatewayCN": "gateway.user"
}' >security-config.json

exec "$@"
