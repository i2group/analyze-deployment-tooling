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

. /opt/db-scripts/environment.sh
. /opt/db-scripts/commonFunctions.sh

file_env 'SA_USERNAME'
file_env 'SA_PASSWORD'
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'DB_TRUSTSTORE_PASSWORD'

set -e

if [[ ${DB_SSL_CONNECTION} == true ]]; then
	file_env 'SSL_CA_CERTIFICATE'
	if [[ -z ${SSL_CA_CERTIFICATE} ]]; then
		echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
		exit 1
	fi
	TMP_SECRETS=/tmp/i2acerts
	CA_CER=${TMP_SECRETS}/CA.cer
	mkdir ${TMP_SECRETS}
	echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

	cp "${CA_CER}" /etc/pki/ca-trust/source/anchors
	update-ca-trust
	for file in /opt/*.sh; do
		sed -i 's/sqlcmd/sqlcmd -N/g' "$file"
	done
fi

if [[ "${1}" == "runSQLQuery" ]]; then
	runSQLQuery "${2}"
elif [[ "${1}" == "runSQLQueryForDB" ]]; then
	runSQLQueryForDB "${2}" "${3}"
else
	set +e
	exec "$@"
fi
