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

retry=0
while true; do
	(/var/db2_setup/lib/setup_db2_instance.sh) && break || {
		if [[ $retry -lt 5 ]]; then
			((retry++))
			sleep 3
		else
			exit 1
		fi
	}
done

USESSL="${SERVER_SSL}"
if [[ ${SERVER_SSL} == "true" ]]; then
	DB_TRUSTSTORE_PASSWORD=$(openssl rand -base64 16)
	export DB_TRUSTSTORE_PASSWORD

	file_env 'SSL_PRIVATE_KEY'
	file_env 'SSL_CERTIFICATE'
	file_env 'SSL_CA_CERTIFICATE'

	if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} || -z ${SSL_CA_CERTIFICATE} ]]; then
		echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE"
		exit 1
	fi

	TMP_SECRETS=/tmp/i2acerts
	KEY=${TMP_SECRETS}/server.key
	CER=${TMP_SECRETS}/server.cer
	CA_CER=${TMP_SECRETS}/CA.cer

	DB_KEYSTORE=${TMP_SECRETS}/keystore.p12
	DB_TRUSTSTORE=${TMP_SECRETS}/truststore.p12

	if [[ -d ${TMP_SECRETS} ]]; then
		rm -r ${TMP_SECRETS}
	fi
	mkdir ${TMP_SECRETS}

	echo "${SSL_PRIVATE_KEY}" >"${KEY}"
	echo "${SSL_CERTIFICATE}" >"${CER}"
	echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

	openssl pkcs12 -export -in ${CER} -inkey "${KEY}" -certfile ${CA_CER} -passout env:DB_TRUSTSTORE_PASSWORD -out "${DB_KEYSTORE}"
	keytool -importcert -noprompt -alias ca -keystore "${DB_TRUSTSTORE}" -file ${CA_CER} -storepass:env DB_TRUSTSTORE_PASSWORD -storetype PKCS12
fi

set +e
exec "$@"
