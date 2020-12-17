# ZooKeeper

The ZooKeeper image for i2 Analyze is built from a Dockerfile that is based on the Dockerfile from Apache ZooKeeper. The Dockerfile is modified to configure ZooKeeper for use with i2 Analyze.

## Building a ZooKeeper image

The ZooKeeper image is built from the Dockerfile located in `images/zookeeper_redhat`.

### Docker build command

The The following `docker build` command builds the ZooKeeper image:

```bash
docker build -t zookeeper_redhat images/zookeeper_redhat
```

## Running a ZooKeeper container

A ZooKeeper container uses the ZooKeeper image. In the `docker run` command, you can use `-e` to pass environment variables to ZooKeeper on the container. The environment variables are described in [environment variables](#environment-variables).

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### Docker run command

The following `docker run` command starts a ZooKeeper container:

```bash
docker run --restart always -d \
   --name "zk1" \
   --net "eia" \
   --net-alias "zk1.eia" \
   -p "8080:8080" \
   -v "zk1_data:/data" \
   -v "zk1_datalog:/datalog" \
   -v "zk1_logs:/logs" \
   -v "/environments/pre-prod/simulated-secret-store/zk1:/run/secrets" \
   -e ZOO_SERVERS="server.1=zk1.eia:2888:3888 server.2=zk2.eia:2888:3888 server.3=zk3.eia:2888:3888" \
   -e ZOO_MY_ID=1 \
   -e ZOO_SECURE_CLIENT_PORT=2281 \
   -e ZOO_CLIENT_PORT=2181 \
   -e ZOO_4LW_COMMANDS_WHITELIST="ruok, mntr, conf" \
   -e SERVER_SSL=true \
   -e SSL_PRIVATE_KEY_FILE="/run/secrets/server.key" \
   -e SSL_CERTIFICATE_FILE="/run/secrets/server.cer" \
   -e SSL_CA_CERTIFICATE_FILE="/run/secrets/CA.cer" \
   "zookeeper_redhat"
```

For an example of the `docker run` command, see [serverFunctions.sh](../../environments/pre-prod/utils/serverFunctions.sh). The `runZK` function takes the following arguments to support running multiple ZooKeeper containers:

1. `CONTAINER` - The name for the container.
1. `FQDN` - The fully qualified domain name for the container.
1. `DATA_VOLUME` - The name for the `data` named volume. For more information, see [Volumes](#volumes).
1. `DATALOG_VOLUME` - The name for the `datalog` named volume. For more information, see [Volumes](#volumes).
1. `LOG_VOLUME` - The name for the `log` named volume. For more information, see [Volumes](#volumes).
1. `HOST_PORT` - The port number on the host machine that is mapped to the port on the container.
1. `ZOO_ID` - An identifier for the ZooKeeper server. For more information, see [Environment variables](#environment-variables).

An example of running Zookeeper container using `runZK` function:
```bash
runZK zk1 zk1.eia zk1_data zk1_datalog zk1_logs 8080 1
```

### Volumes

A named volume is used to persist data and logs that are generated and used in the ZooKeeper container, outside of the container. 

To configure the ZooKeeper container to use the volume, specify the `-v` option with the name of the volume and the path where the directory is mounted in the container. By setting `-v` option in the docker run command, a named volume is created. For ZooKeeper, the directories that must be mounted are `/data`, `/datalog`, `/logs`.

For example:
```sh
-v zk1_data:/data \
-v zk1_datalog:/datalog \
-v zk1_log:/logs \
```

A unique volume name must be used for each ZooKeeper container.

For more information, see [Where to store data](https://hub.docker.com/_/zookeeper).

### Bind mounts

**Secrets**:  
A directory that contains all of the secrets that this tool requires. Specifically this includes credentials to access zookeeper and certificates used in SSL.  
The directory is mounted to a location in the container defined by the `CONTAINER_SECRETS_DIR` environment variable. This can then be used by other environment variables such as `SSL_PRIVATE_KEY_FILE` to locate the secrets. 
In a production environment, the orchestration environment can provide the secrets to the file system or the secrets can be passed in via environment variables. The mechanism that is used here simulates the orchestration system providing the secrets as files. This is achieved by using a bind mount. In production this would not be required.

### Environment variables

To configure ZooKeeper, you can provide environment variables to the Docker container in the `docker run` command. The `zoo.cfg` configuration file for ZooKeeper is generated from the environment variables passed to the container.

The following table describes the mandatory environment variables for running ZooKeeper in replicated mode:

| Environment variable | Description |
|----------------------|-------------|
| `ZOO_SERVERS` | Specified the list of ZooKeeper servers in the ZooKeeper ensemble. Servers are specified in the following format: `server.id=<address1>:<port1>:<port2>;<client port>`. |
| `ZOO_MY_ID` | An identifier for the ZooKeeper server. The identifier must be unique within the ensemble. |
| `ZOO_CLIENT_PORT` | Specifies the port number for client connections. Maps to the `clientPort` configuration parameter. |

For more information, see [ZooKeeper Docker hub](https://hub.docker.com/_/zookeeper/).

The following table described the security environment variables:

| Environment variable      | Description |
|-------------------------- |-------------|
| `ZOO_SECURE_CLIENT_PORT`  | Specifies the port number for client connections that use SSL. Maps to the `secureClientPort` configuration parameter. |
| `SOLR_ZOO_SSL_CONNECTION` | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).|
| `SERVER_SSL`              | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).| 
| `SSL_PRIVATE_KEY_FILE`    | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).| 
| `SSL_CERTIFICATE_FILE`    | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).|
| `SSL_CA_CERTIFICATE_FILE` | See [Secure Environment variables](../security%20and%20users/security.md#secure-environment-variables).|

For more information about securing ZooKeeper, see [Encryption, Authentication, Authorization Options](https://zookeeper.apache.org/doc/r3.6.2/zookeeperAdmin.html#sc_authOptions).


The following table describes the environment variables that are supported:

| Environment variable | Description |
|----------------------|-------------|
| `ZOO_TICK_TIME` | The length of a single tick, which is the basic time unit used by ZooKeeper, as measured in milliseconds. Maps to the `tickTime` configuration parameter. The default value is `2000`. |
| `ZOO_INIT_LIMIT` | Amount of time, in ticks, to allow followers to connect and sync to a leader. Increase this value as needed, if the amount of data managed by ZooKeeper is large. Maps to the `initLimit` configuration parameter. The default value is `10`. |
| `ZOO_SYNC_LIMIT` | Amount of time, in ticks, to allow followers to sync with ZooKeeper. If followers fall too far behind a leader, they will be dropped. Maps to the `syncLimit` configuration parameter. The default value is `5`. |
| `ZOO_AUTOPURGE_PURGEINTERVAL` | The time interval in hours for which the purge task has to be triggered. Set to a positive integer (1 and above) to enable the auto purging. Maps to the `autopurge.purgeInterval` configuration parameter. The default value is `24`. |
| `ZOO_AUTOPURGE_SNAPRETAINCOUNT` | When auto purge is enabled, ZooKeeper retains the specified number of most recent snapshots and the corresponding transaction logs in the dataDir and dataLogDir respectively and deletes the rest. Maps to the `autopurge.snapRetainCount` setting. The default value is `3`. |
| `ZOO_MAX_CLIENT_CNXNS` | Limits the number of concurrent connections (at the socket level) that a single client, identified by IP address, may make to a single member of the ZooKeeper ensemble. Maps to the `maxClientCnxns` configuration parameter. The default value is `60`. |
| `ZOO_STANDALONE_ENABLED` | When set to `true`, if ZooKeeper is started with a single server the ensemble will not be allowed to grow, and if started with more than one server it will not be allowed to shrink to contain fewer than two participants. Maps to the `standaloneEnabled` configuration parameter. The default value is `true`. |
| `ZOO_ADMINSERVER_ENABLED` | Enables the AdminServer. The AdminServer is an embedded Jetty server that provides an HTTP interface to the four letter word commands. Maps to the `admin.enableServer` configuration parameter. The default value is `true`. |
| `ZOO_DATA_DIR` | The location where ZooKeeper stores in-memory database snapshots. Maps to the `dataDir` configuration parameter. The default value is `/data`. |
| `ZOO_DATA_LOG_DIR` | The location where ZooKeeper writes the transaction log. Maps to the `dataLogDir` configuration parameter. The default value is `/datalog`. |
| `ZOO_CFG_EXTRA` | You can add arbitrary configuration parameters, that are not exposed as environment variables in ZooKeeper, to the Zookeeper configuration file using this variable. |
| `ZOO_CONF_DIR` | Specifies the location for the ZooKeeper configuration directory. The default value is `/conf`. |
| `ZOO_LOG_DIR` | Specifies the location for the ZooKeeper logs directory. The default value is `/logs`. |

For more information about configuring ZooKeeper, see:
* [Configuration Parameters](https://zookeeper.apache.org/doc/r3.5.5/zookeeperAdmin.html#sc_configuration)
* [ZooKeeper Docker hub](https://hub.docker.com/_/zookeeper/).

> Note: Values that are specified in the environment variables override any configuration that is included in the `ZOO_CFG_EXTRA` block.
