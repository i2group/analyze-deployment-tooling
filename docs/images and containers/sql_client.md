# SQL Server Client

An SQL Server Client container is an ephemeral container that is used to run the `sqlcmd` commands to create and configure the database.

## <a name="buildingansqlserverclientimage"></a> Building an SQL Server Client image

The SQL Server Client is built from a Dockerfile that is based on [Microsoft SQL Server](https://hub.docker.com/_/microsoft-mssql-server).

The SQL Server Client image is built from the Dockerfile in `images/sql_client`.

### <a name="dockerbuildcommand"></a> Docker build command

The following `docker build` command builds the SQL Server Client image:

```bash
docker build -t sqlserver_client_redhat images/sql_client
```

## <a name="runningasqlserverclientcontainer"></a> Running a SQL Server Client container

An SQL Server Client container uses the SQL Server Client image. In the `docker run` command, you can use `-e` to pass environment variables to the container. The environment variables are described in [environment variables](#environmentvariables).

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### <a name="dockerruncommand"></a> Docker run command

The following `docker run` command runs a SQL Server Client container:

```bash
docker run \
    --rm \
    --name "sqlclient" \
    --network "eia" \
    -v "pre-reqs/i2analyze/toolkit:/opt/toolkit" \
    -v "/environments/pre-prod/database-scripts/generated:/opt/databaseScripts/generated" \
    -e DB_SERVER="sqlserver.eia" \
    -e DB_PORT=1433 \
    -e DB_NAME="ISTORE" \
    -e GENERATED_DIR="/opt/databaseScripts/generated" \
    -e DB_USERNAME="dba" \
    -e DB_PASSWORD="DBA_PASSWORD" \
    -e DB_SSL_CONNECTION=true \
    -e SSL_CA_CERTIFICATE="SSL_CA_CERTIFICATE" \
    "sqlserver_client_redhat" "$@"
```

For an example of the `docker run` command, see `runSQLServerCommandAsETL` function in `clientFunctions.sh` script.
For an example of how to use `runSQLServerCommandAsETL` function, see [runSQLServerCommandAsETL](../tools%20and%20functions/client_functions.md#runsqlservercommandasetl).
> Note: you can run SQL Server Client container as different users, see [`runSQLServerCommandAsDBA`](../tools%20and%20functions/client_functions.md#runsqlservercommandasdba), [`runSQLServerCommandAsSA`](../tools%20and%20functions/client_functions.md#runsqlservercommandassa)

## <a name="bindmounts"></a> Bind mounts

- **Secrets**:  
A directory that contains all of the secrets that this tool requires. Specifically this includes credentials to access zookeeper and certificates used in SSL.  
The directory is mounted to a location in the container defined by the `CONTAINER_SECRETS_DIR` environment variable. This can then be used by other environment variables such as `SSL_CA_CERTIFICATE_FILE` to locate the secrets. 
In a production environment, the orchestration environment can provide the secrets to the file system or the secrets can be passed in via environment variables. The mechanism that is used here simulates the orchestration system providing the secrets as files. This is achieved by using a bind mount. In production this would not be required.

- **Toolkit**:  
For the SQL Server Client to use the tools in `/opt/toolkit/i2-tools/scripts`, 
the toolkit must be mounted into the container.  
In the example scripts, this is defaulted to `/opt/toolkit`.

- **Generated scripts directory**:  
Some of the i2 Analyze tools generate scripts to be run against the Information Store database. For the SQL Server Client to run these scripts, the directory where they are generated must be mounted into the container.  
In the example scripts, this is defaulted to `/database-scripts/generated`. The `GENERATED_DIR` environment variable must specify the location where the generated scripts are mounted.

## <a name="environmentvariables"></a> Environment variables

|Environment Variable | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| `DB_SERVER`         | The fully qualified domain name of the database server.        |
| `DB_PORT`           | Specifies the port number to connect to the Information Store. |
| `DB_NAME`           | The name of the Information Store database.                    |
| `DB_USERNAME`       | The user.                                                      |
| `DB_PASSWORD`       | The password.                                                  |
| `GENERATED_DIR`     | The root location where any generated scripts are created.     |

The following environment variables enable you use SSL

| Environment variable | Description                                                   |
| -------------------- | ------------------------------------------------------------- |
| `DB_SSL_CONNECTION`  | See [Secure Environment variables](../security%20and%20users/security.md#secureenvironmentvariables).        |
| `SSL_CA_CERTIFICATE` | See [Secure Environment variables](../security%20and%20users/security.md#secureenvironmentvariables).        |

## <a name="commandparsing"></a> Command parsing

When commands are passed to the Solr client by using the `"$@"` notation, the command that is passed to the container must be escaped correctly. On the container, the command is run using `docker exec "$@"`. Because the command is passed to the `docker run` command using `bash -c`, the command must be maintained as a double quoted string.

For example:
```bash
    runSQLServerCommandAsETL 
    bash -c 
    "/opt/mssql-tools/bin/sqlcmd -N -b
    -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} 
    -Q \"BULK INSERT ${STAGING_SCHEMA}.${table_name} 
    FROM '/tmp/examples/data/${BASE_DATA}/${csv_and_format_file_name}.csv' 
    WITH (FORMATFILE = '/tmp/examples/data/${BASE_DATA}/sqlserver/format-files/${csv_and_format_file_name}.fmt', FIRSTROW = 2)\""
```

Different parts of the command must be escaped in different ways:
- `\${DB_SERVER}`,`\${DB_USERNAME}`, `\${DB_PASSWORD}`, and `\${DB_NAME}`  
   Because the command uses the container's local environment variables to obtain the values of these variables, the `$` is escaped by a `\`.  
   `${DB_PORT}` is not escaped because this is an environment variable available to the script calling the client function.

- `\"BULK INSERT ${STAGING_SCHEMA}.${table_name} ... FIRSTROW = 2)\"`  
   The string value for the `-Q` argument must be surrounded by `"` when it is run on the container. The surrounding `"` are escaped with `\`.
   The variables that are not escaped in the string are evaluated outside of the container when the function is called.