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

# Update /create-database-storage.db2 file
tmp_create_db_storage_file_path="/tmp/create-database-storage.db2"
cp "${DB2_STATIC_DIR}/create-database-storage.db2" "${tmp_create_db_storage_file_path}"
sed -i "s/\${AttachScript}/ATTACH TO \"${DB_NODE}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD//\//\\/}\";/g" "${tmp_create_db_storage_file_path}"
sed -i "s/\${DetachScript}/DETACH;/g" "${tmp_create_db_storage_file_path}"
sed -i "s/\$(DatabasePath)/${DB_LOCATION_DIR//\//\\/}/g" "${tmp_create_db_storage_file_path}"
sed -i "s/\${ConnectScript}/CONNECT TO \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD//\//\\/}\";/g" "${tmp_create_db_storage_file_path}"
sed -i "s/\${GrantScript}//g" "${tmp_create_db_storage_file_path}"
sed -i "s/\${CustomScript}//g" "${tmp_create_db_storage_file_path}"

# Run /create-database-storage.db2 file
db2 -tf "${tmp_create_db_storage_file_path}"
rm "${tmp_create_db_storage_file_path}"

db2se enable_db "${DB_NAME}" -userid "${DB_USERNAME}" -pw "${DB_PASSWORD}"

db2 "CONNECT TO \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""

db2 -tsf "${DB2_STATIC_DIR}/0020-create-bufferpools.sql"
db2 -tsf "${DB2_STATIC_DIR}/0030-create-tablespaces.sql"
db2 -tsf "${DB2_STATIC_DIR}/0060-create-roles.sql"

echo "SUCCESS: The execution of the database creation scripts is complete"

set +e