# Liberty

In a containerized deployment, you configure the i2 Analyze application and Liberty in an image that is layered on top of the *liberty_ubi_base* image. The *liberty_ubi_base* contains static configuration and application jars that are required by i2 Analyze and should not be changed. 

## Configuring the Liberty server

Liberty is configured by exception. The runtime environment operates from a set of built-in configuration default settings, and you only need to specify configuration that overrides those default settings. You do this by editing either the `server.xml` file or another XML file that is included in `server.xml` at run time.

In a containerized deployment of i2 Analyze, a `server.xml` file is provided for you. To provide or modify any values, you specify a number of [environment variables](#environment-variables) when you run a Liberty container.

Additionally, you can extend the `server.xml` by using the provided `server.extensions.xml` in the i2 Analyze configuration. Any elements that you add to the extensions file are included in the `server.xml` when you run a Liberty container.

## Configuring the i2 Analyze application

The contents of the `configuration` directory must be copied into the `images/liberty_ubi_combined/classes` directory. The contents of the `classes` directory is added to the configured Liberty image when the image is built. If you make changes to the configuration, you must copy the changes to the `classes` directory and rebuild the configured image.

>Note: The system match rules are configured differently. The application is updated to use the `system-match-rules.xml` from the Solr client command line. For more information about updating the system match rules, see ... .

## Building a configured Liberty image

The *configured image* is built from the base image. The configured image contains the i2 Analyze application and Liberty configuration that is required to start the i2 Analyze application. When you change the configuration, the configured image must be rebuilt to reflect the changes.

### Docker build command

The configured image is built from the Dockerfile in `images/liberty_ubi_combined`. The following `docker build` command builds the configured image:

```bash
docker build -t liberty_configured_redhat images/liberty_ubi_combined
```

An example of providing the configuration to the classes directory and building the image is included in the `buildLibertyConfiguredImage` function in the `serverFunctions.sh` script.

## Running a Liberty container

A Liberty container uses the configured image. In the `docker run` command, you can use `-e` to pass environment variables to Liberty on the container. The environment variables are described in [environment variables](#environment-variables)

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### Docker run command

The following `docker run` command runs a Liberty container:

```bash
docker run -m 1g -d \
  --name "liberty1" \
  --network "eia" \
  --net-alias "liberty1.eia" \
  -p "9045:9443" \
  -v "/environments/pre-prod/simulated-secret-store/liberty1:/run/secrets" \
  -v "liberty1_data:/data" \
  -e LICENSE="accept" \
  -e FRONT_END_URI="https://liberty.eia:9045/opal" \
  -e DB_DIALECT="sqlserver" \
  -e DB_SERVER="sqlserver.eia" \
  -e DB_PORT=1433 \
  -e DB_USERNAME="i2analyze" \
  -e DB_PASSWORD_FILE="/run/secrets/DB_PASSWORD" \
  -e ZK_HOST="zk1.eia:2281,zk2.eia:2281,zk3.eia:2281" \
  -e ZOO_DIGEST_USERNAME="solr" \
  -e ZOO_DIGEST_PASSWORD_FILE="/run/secrets/ZK_DIGEST_PASSWORD" \
  -e SOLR_HTTP_BASIC_AUTH_USER="liberty" \sp
  -e SOLR_HTTP_BASIC_AUTH_PASSWORD_FILE="/run/secrets/SOLR_APPLICATION_DIGEST_PASSWORD" \
  -e DB_SSL_CONNECTION=true \
  -e SOLR_ZOO_SSL_CONNECTION=true \
  -e SERVER_SSL=true \
  -e SSL_PRIVATE_KEY_FILE="/run/secrets/server.key" \
  -e SSL_CERTIFICATE_FILE="/run/secrets/server.cer" \
  -e SSL_CA_CERTIFICATE_FILE="/run/secrets/CA.cer" \
  -e GATEWAY_SSL_CONNECTION=true \
  -e SSL_OUTBOUND_PRIVATE_KEY_FILE="/run/secrets/gateway_user.key" \
  -e SSL_OUTBOUND_CERTIFICATE_FILE="/run/secrets/gateway_user.cer" \
  -e LIBERTY_HADR_MODE=1 \
  -e LIBERTY_HADR_POLL_INTERVAL=1 \
  liberty_configured_redhat
```

For an example of the `docker run` command, see [serverFunctions.sh](../../environments/pre-prod/utils/serverFunctions.sh). The `runLiberty` function takes the following arguments to support running multiple Liberty containers:
1. `CONTAINER` - The name for the container.
1. `FQDN` - The fully qualified domain name for the container and the Solr host.
1. `VOLUME` - the name for the named volume of the Liberty container. For more information, see [Volumes](#volumes).
1. `HOST_PORT` - The port number on the host machine that is mapped to the port on the container.
1. `KEY_FOLDER` - The folder with keys and certificates for the container. For more information, see [Security](../security%20and%20users/security.md).

An example of running Liberty container by using `runLiberty` function:
```bash
runLiberty liberty1 liberty1.eia liberty1_data 9045 liberty1
```
### Volumes
A named volume is used to persist data, which is generated and used in the Liberty container, outside of the container. 

To configure the Liberty container to use the volume, specify the `-v` option with the name of the volume and the path where the directory is mounted in the container. By setting `-v` option in the docker run command, a named volume is created. For Liberty, the directory that is mounted must be `/data`, this directory folder stores: jobs, record groups and charts.

For example:
```sh
-v liberty_data:/data
```

### Bind mounts

**Secrets**:  
A directory that contains all of the secrets that this tool requires. Specifically this includes credentials to access ZooKeeper, the database, and the certificates used in SSL.  
The directory is mounted to a location in the container defined by the `CONTAINER_SECRETS_DIR` environment variable. This can then be used by other environment variables such as `ZOO_DIGEST_USERNAME_FILE` to locate the secrets.  
In a production environment, the orchestration environment can provide the secrets to the file system or the secrets can be passed in via environment variables. The mechanism that is used here simulates the orchestration system providing the secrets as files. This is achieved by using a bind mount. In production this would not be required.

### Environment variables

To configure the Liberty server, you provide environment variables to the Docker container in the `docker run` command.

The following table describes the supported environment variables that you can use:

| Environment variable | Description |
|----------------------|-------------|
| `FRONT_END_URI` | The URI that clients use to connect to i2 Analyze. For more information, see [Specifying the connection URI](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/t_edge_url.html). |
| `DB_DIALECT`| Specifies which database management system to configure i2 Analyze for. In this release, it can be set to `sqlserver`. For more information, see [properties.microsoft.sqlserver](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.liberty.autogen.base.doc/ae/rwlp_config_dataSource.html#properties.microsoft.sqlserver). |
| `DB_SERVER` | Specifies the fully qualified domain name of the database server to connect to. The value populates the `serverName` attribute in the Liberty server configuration. For more information, see [properties.microsoft.sqlserver](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.liberty.autogen.base.doc/ae/rwlp_config_dataSource.html#properties.microsoft.sqlserver). |
| `DB_PORT`| Specifies the port number of the SQL Server database to connect to. The value populates the `portNumber` attribute in the Liberty server configuration. You can specify `DB_PORT` or `DB_INSTANCE`. For more information, see [properties.microsoft.sqlserver](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.liberty.autogen.base.doc/ae/rwlp_config_dataSource.html#properties.microsoft.sqlserver). |
| `DB_USERNAME`| The database user that is used by Liberty to connect to the database. |
| `DB_PASSWORD`| The database user password. |
| `ZK_HOST` | Specifies the connection string for each ZooKeeper server to connect to. To connect to more than one ZooKeeper server, the values must be in comma separated. The connection string must be in the following format: `<hostname>:<port>,<hostname>:<port>`. |
| `SOLR_HTTP_BASIC_AUTH_USER`| The Solr user that Liberty uses to connect to Solr. This is not an administrator user. |
| `SOLR_HTTP_BASIC_AUTH_PASSWORD`| The Solr user password. |
| `ZOO_DIGEST_USERNAME`| The ZooKeeper user that is used by Liberty to connect to ZooKeeper. |
| `ZOO_DIGEST_PASSWORD`| The ZooKeeper user password. |

The following environment variables enable you to use SSL:

| Environment variable              | Description |
| --------------------------------- | ----------- |
| `DB_SSL_CONNECTION`               | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SOLR_ZOO_SSL_CONNECTION`         | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SERVER_SSL`                      | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SSL_PRIVATE_KEY_FILE`            | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). | 
| `SSL_CERTIFICATE_FILE`            | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SSL_CA_CERTIFICATE_FILE`         | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). | 
| `GATEWAY_SSL_CONNECTION`          | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SSL_OUTBOUND_PRIVATE_KEY_FILE`   | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |
| `SSL_OUTBOUND_CERTIFICATE_FILE`   | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables). |

### Liberty HADR
You can run Liberty in an active/active configuration with multiple Liberty containers. In an active/active configuration, multiple instance of the i2 Analyze application run concurrently on multiple Liberty containers. One instance of the i2 Analyze application is determined to be the leader at any given time.

The following tables describes the environment variables that you can use to configure HADR:

| Environment variable | Description |
|----------------------|-------------|
| `LIBERTY_HADR_MODE`| Can be set to 1 or 0. If set to 1, Liberty starts in `HADR` mode. The default is 0. |
| `LIBERTY_HADR_POLL_INTERVAL` | The interval in minutes to poll for liberty leadership status. The default is 5. |
| `LIBERTY_HADR_MAX_ERRORS` | The maximum number of errors allowed before Liberty initiates a leadership poll. The time span in which the errors can occur is determined by `LIBERTY_HADR_ERROR_TIME_SPAN`. The default is 5. |
| `LIBERTY_HADR_ERROR_TIME_SPAN` | The time span in seconds for the `LIBERTY_HADR_MAX_ERRORS` to occur within. The default is 30. |

