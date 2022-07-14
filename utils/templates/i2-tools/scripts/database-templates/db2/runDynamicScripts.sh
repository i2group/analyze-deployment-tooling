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

DB2_DYNAMIC_DIR="${GENERATED_DIR}/dynamic"
DB2_STATIC_DIR="${GENERATED_DIR}/static"

db2 "CATALOG TCPIP node \"${DB_NODE}\" REMOTE \"${DB_SERVER}\" SERVER \"${DB_PORT}\""
db2 "CATALOG DATABASE \"${DB_NAME}\" at node \"${DB_NODE}\""
db2 "CONNECT TO \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""

# Run dynamic scripts
db2 -tsf "${DB2_DYNAMIC_DIR}/0215-insert-schema.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/0220-insert-metadata.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/0230-insert-item-metadata.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/0320-create-links-table.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/0330-create-links-table-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1000-create-item-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1010-create-item-tables-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1020-create-item-provenance-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1030-create-item-provenance-tables-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1040-create-item-source-identifier-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1200-create-item-correlation-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1210-create-item-correlation-tables-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1220-create-item-provenance-extension-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1230-create-item-provenance-extension-tables-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1240-create-circular-link-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1250-create-circular-link-tables-indexes.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1410-create-item-notes-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1420-create-item-source-reference-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1430-create-source-reference-circular-link-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1500-create-binary-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1510-create-binary-text-extract-tables.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1600-create-item-views.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1610-create-retrieval-views.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1620-create-provenance-views.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1630-create-links-view.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/1640-create-source-identifier-views.sql"
db2 -tsf "${DB2_DYNAMIC_DIR}/G010-register-item-geo-columns.sql"

# Run static scripts
db2 -tsf "${DB2_STATIC_DIR}/P010-create-public-ingestion-report-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/P020-create-public-deletion-by-rule-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/P030-create-public-upgrade-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/P040-create-public-third-party-notifications-routines.sql" || echo "Temporarily Ignoring Failure"
db2 -tsf "${DB2_STATIC_DIR}/P050-create-public-third-party-notifications-view.sql"
db2 -tsf "${DB2_STATIC_DIR}/P060-create-public-chart-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/P310-create-public-deletion-by-rule-routines.sql"
db2 -tsf "${DB2_STATIC_DIR}/P510-grant-deletion-by-rule-permissions.sql"
db2 -tsf "${DB2_STATIC_DIR}/T020-create-toolkit-routines.sql"
db2 -tsf "${DB2_STATIC_DIR}/X010-populate-configuration-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/X011-set-data-source-id.sql"

# The following will generate a warning on clean install
# +w flag will ensure it doesn't return non-zero exit code.
db2 +w -tsf "${DB2_STATIC_DIR}/update_version.sql"

echo "SUCCESS: The execution of the dynamic scripts is complete"

set +e
