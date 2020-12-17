#!/bin/bash
# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

set -e

. /opt/db-scripts/environment.sh

file_env 'SA_OLD_PASSWORD'
file_env 'SA_NEW_PASSWORD'

/opt/mssql-tools/bin/sqlcmd -b -S "${DB_SERVER},${DB_PORT}" -U "${SA_USERNAME}" -P "${SA_OLD_PASSWORD}" -Q "ALTER LOGIN ${SA_USERNAME} WITH PASSWORD=\"${SA_NEW_PASSWORD}\""

set +e