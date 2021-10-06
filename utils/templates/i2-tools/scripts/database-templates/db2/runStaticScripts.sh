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

DB2_STATIC_DIR="${GENERATED_DIR}/static"

db2 "CATALOG TCPIP node \"${DB_NODE}\" REMOTE \"${DB_SERVER}\" SERVER \"${DB_PORT}\""
db2 "CATALOG DATABASE \"${DB_NAME}\" at node \"${DB_NODE}\""
db2 "CONNECT TO \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""

db2 -tsf "${DB2_STATIC_DIR}/0110-create-ingestion-constants.sql"
db2 -tsf "${DB2_STATIC_DIR}/0200-create-metadata-i2a-schema-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0210-create-metadata-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0213-create-metadata-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/0250-create-metadata-routines.sql"
db2 -tsf "${DB2_STATIC_DIR}/0300-create-support-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0340-create-sequences.sql"
db2 -tsf "${DB2_STATIC_DIR}/0400-create-vq-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0500-create-ingestion-report-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0510-create-ingestion-batch-items-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0520-create-ingestion-history-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0530-create-subscriber-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0540-create-ingestion-report-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/0550-create-ingestion-report-indexes.sql"
db2 -tsf "${DB2_STATIC_DIR}/0700-create-find-path-temporary-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0710-create-find-path-results-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0730-create-analytics-routines-module.sql"
db2 -tsf "${DB2_STATIC_DIR}/0740-create-find-path-routine.sql"
db2 -tsf "${DB2_STATIC_DIR}/0750-create-saved-vq-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0760-create-vq-subscription-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0770-create-notifications-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0780-create-user-settings-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0790-create-saved-vq-indexes.sql"
db2 -tsf "${DB2_STATIC_DIR}/0900-create-user-item-flags-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/0910-create-webchart-session-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/1400-create-item-semaphore-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/1401-create-link-semaphore-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/2010-create-deletion-by-rule-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/2020-create-deletion-by-rule-routines.sql"
db2 -tsf "${DB2_STATIC_DIR}/2040-create-deletion-by-rule-schedule.sql"
db2 -tsf "${DB2_STATIC_DIR}/3000-create-configuration-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/3010-create-configuration-views.sql"
db2 -tsf "${DB2_STATIC_DIR}/3020-create-configuration-routines.sql"
db2 -tsf "${DB2_STATIC_DIR}/3030-create-configuration-triggers.sql"
db2 -tsf "${DB2_STATIC_DIR}/3110-create-upgrade-tables.sql"
db2 -tsf "${DB2_STATIC_DIR}/3120-create-upgrade-views.sql"

echo "SUCCESS: The execution of the static scripts is complete"

set +e
