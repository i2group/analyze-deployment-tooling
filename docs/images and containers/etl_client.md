# ETL Client

An ETL Client container is an ephemeral container that is used to run ETL tasks.

## Building an ETL Client image

ETL Client image is built is built from the Dockerfile in `images/etl_client`. ETL Client image uses the i2Analyze Tools image as the base image.

### Docker build command

The following `docker build` command builds the ETL Client image:

```sh
docker build -t "etlclient_redhat" "/images/etl_client" \
    --build-arg USER_UID="$(id -u "${USER}")" \
    --build-arg BASE_IMAGE="i2a_tools_redhat"
```

The `--build-arg` flag is used to provide your local user ID to the Docker image when it is built. sThe value of `$USER` comes from your shell.

For examples of the build commands, see the [buildImages.sh](../../environments/pre-prod/buildImages.sh) script. 

## Running an ETL Client container

A ETL Client container uses ETL Client image. In the `docker run` command, you can use `-e` to pass environment variables to the container. The environment variables are described in [environment variables](#environment-variables)

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### Docker run command

The following `docker run` command runs the ETL Client container:

```sh
docker run --rm \
    --name "etl_client" \
    --network "eia" \
    --user "$(id -u "${USER}"):$(id -u "${USER}")" \
    -v "/environments/pre-prod/configuration/logs:/opt/configuration/logs" \
    -v "/prereqs/i2analyze/toolkit/examples/data:/tmp/examples/data" \
    -e DB_SERVER="sqlserver.eia" \
    -e DB_PORT=1433 \
    -e DB_NAME="ISTORE" \
    -e DB_DIALECT="sqlserver" \
    -e DB_OS_TYPE="UNIX" \
    -e DB_INSTALL_DIR="/opt/mssql-tools" \
    -e DB_LOCATION_DIR="/var/opt/mssql/data" \
    -e JAVA_HOME="/opt/java/openjdk/bin/java" \
    -e DB_USERNAME="i2etl" \
    -e DB_PASSWORD="DB_PASSWORD" \
    -e DB_SSL_CONNECTION=true \
    -e SSL_CA_CERTIFICATE="SSL_CA_CERTIFICATE" \
    "etlclient_image" "$@"
```

For an example of the `docker run` command, see `runEtlToolkitToolAsi2ETL` function in [clientFunctions.sh](../../environments/pre-prod/utils/clientFunctions.sh) script.
For an example of how to use `runEtlToolkitToolAsi2ETL` function, see [runEtlToolkitToolAsi2ETL](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl).

## Environment variables

The ETl Client is built on top of the SQL Client. Any environment variables referenced in the [SQL Client](./sql_client.md#environment-variables) can be used in the Etl Client.

### Additional Environment variables

|Environment Variable | Description                                                                     |
| ------------------- | ------------------------------------------------------------------------------- |
| `DB_DIALECT`        | The database dialect. Currently only `sqlserver` is supported                   |
| `DB_OS_TYPE`        | The Operating System that the database is on. Can be `UNIX`, `WIN`, or `AIX`.   |
| `DB_INSTALL_DIR`    | Specifies the database CMD location.                                            |
| `DB_LOCATION_DIR`   | Specifies the location of the database.                                         |
| `JAVA_HOME`         | Specifies the location on Java.                                                 |

## Useful links

- [Documentation for adding an ingestion source using the Etl toolkit](https://www.ibm.com/support/knowledgecenter/en/SSXVTH_4.3.0/com.ibm.i2.iap.admin.ingestion.doc/define_ingestion_source.html?cp=SSXVXZ_2.3.0)
