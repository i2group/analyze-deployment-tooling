# SQL Server

In a containerized deployment, the database is located on a SQL Server container.

## Building a SQL Server image

SQL Server is built from a Dockerfile that is based on the Dockerfile from [Microsoft SQL Server](https://hub.docker.com/_/microsoft-mssql-server).

The SQL Server image is built from the Dockerfile in `images/sql_server`.

### Docker build command

The following `docker build` command builds the SQL Server image:

```bash
docker build -t sqlserver_redhat images/sqlserver
```
For examples of the build commands, see `buildImages.sh` script. 

## Running a SQL Server container

A SQL Server container uses the SQL Server image. In the `docker run` command, you can use `-e` to pass environment variables to the container. The environment variables are described in [environment variables](#environment-variables).

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### Docker run command

The following `docker run` command runs a SQL Server container:

```bash
docker run -d \
   --name "sqlserver" \
   --network "eia" \
   --net-alias "sqlserver.eia" \
   -p "1433:1433" \
   -v "sqlserver_data:/var/opt/mssql" \
   -v "/environments/pre-prod/simulated-secret-store/sqlserver:/run/secrets/" \
   -v "/i2analyze/toolkit/examples/data:/tmp/examples/data" \
   -e ACCEPT_EULA="Y" \
   -e MSSQL_AGENT_ENABLED=true \
   -e MSSQL_PID="Developer" \
   -e SA_PASSWORD_FILE="/run/secrets/SA_PASSWORD_FILE" \
   -e SERVER_SSL=true \
   -e SSL_PRIVATE_KEY_FILE="/run/secrets/server.key" \
   -e SSL_CERTIFICATE_FILE="/run/secrets/server.cer" \
   "sqlserver_redhat"
```

For an example of the `docker run` command, see [serverFunctions.sh](../../environments/pre-prod/utils/serverFunctions.sh). The `runSQLServer` does not take any arguments.

### Volumes

A named volume is used to persist data and logs that are generated and used in the SQL Server container, outside of the container. 

To configure the SQL Server container to use the volume, specify the `-v` option with the name of the volume and the path where the directory is mounted in the container. By setting `-v` option in the docker run command, a named volume is created. For SQL Server, the path to the directory that must be mounted is `/var/opt/mssql`.
For example:
```sh
-v sqlvolume:/var/opt/mssql
```

For more information, see [Use Data Volume Containers](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-docker-container-configure?view=sql-server-ver15&pivots=cs1-bash#use-data-volume-containers).

### Bind mounts

- **Secrets**:  
A directory that contains all of the secrets that this tool requires. Specifically this includes credentials to access zookeeper and certificates used in SSL.  
The directory is mounted to a location in the container defined by the `CONTAINER_SECRETS_DIR` environment variable. This can then be used by other environment variables such as `SSL_PRIVATE_KEY_FILE` to locate the secrets.  
In a production environment, the orchestration environment can provide the secrets to the file system or the secrets can be passed in via environment variables. The mechanism that is used here simulates the orchestration system providing the secrets as files. This is achieved by using a bind mount. In production this would not be required.

- **Example Data**:  
To demonstrate ingesting data into the Information Store, the i2 Analyze toolkit is mounted to `/tmp/examples/data` in the container.

### Environment variables

|Environment Variable           | Description  |
| ----------------------------- | ------------ |
| `ACCEPT_EULA`                 | Set to `Y` to confirm your acceptance of the [End-User Licensing Agreement](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15#environment-variables). |
| `MSSQL_AGENT_ENABLED`         | For more information see [Configure SQL Server settings with environment variables on Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15#environment-variables) |
| `MSSQL_PID`                   | For more information see [Configure SQL Server settings with environment variables on Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15#environment-variables) |
| `SA_PASSWORD`                 | The administrator user's password. |

The following environment variables enable you to use SSL:

| Environment variable   | Description   |
| ---------------------- | ------------- |
| `SERVER_SSL`           | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).|
| `SSL_PRIVATE_KEY_FILE` | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).| 
| `SSL_CERTIFICATE_FILE` | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).|

For more information about the SSL in SQLServer, see [Specify TLS settings](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-mssql-conf?view=sql-server-ver15#tls).