#!/bin/bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)

set -e

SQLSERVER_STATIC_DIR="${GENERATED_DIR}/static"

# Update /create-database-storage.sql file
tmp_create_db_storage_file_path="/tmp/create-database-storage.sql"
cp "${SQLSERVER_STATIC_DIR}/create-database-storage.sql" "${tmp_create_db_storage_file_path}"
sed -i "s/\${CustomScript}//g" "${tmp_create_db_storage_file_path}"

# Run /create-database-storage.db2 file
${SQLCMD} ${SQLCMD_FLAGS} -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -r -i "${tmp_create_db_storage_file_path}"
rm "${tmp_create_db_storage_file_path}"

${SQLCMD} ${SQLCMD_FLAGS} -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -r -d "${DB_NAME}" -i "${SQLSERVER_STATIC_DIR}/0001-create-schemas.sql" -I
${SQLCMD} ${SQLCMD_FLAGS} -S "${DB_SERVER},${DB_PORT}" -U "${DB_USERNAME}" -P "${DB_PASSWORD}" -r -d "${DB_NAME}" -i "${SQLSERVER_STATIC_DIR}/0060-create-roles.sql" -I

echo "SUCCESS: The execution of the database creation scripts is complete"

set +e