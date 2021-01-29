# Solr Client

A Solr Client container is an ephemeral container that is used to run Solr commands.

## <a name="buildingasolrclientcontainer"></a> Building a Solr Client container

The Solr Client uses the same image as the Solr Server container. For more information about building the Solr image, see [Solr](./solr.md).

## <a name="runningasolrclientcontainer"></a> Running a Solr Client container

A Solr Client container uses the Solr image. In the `docker run` command, you can use `-e` to pass environment variables to Solr on the container. The environment variables are described in [environment variables](#environmentvariables)

For more information about the command, see [docker run reference](https://docs.docker.com/engine/reference/run/).

### <a name="dockerruncommand"></a> Docker run command

The following `docker run` command runs a Solr Client container:

```bash
docker run --rm \
    --net "eia" \
    -v "/environments/pre-prod/configuration:/opt/configuration" \
    -e SOLR_ADMIN_DIGEST_USERNAME="solr" \
    -e SOLR_ADMIN_DIGEST_PASSWORD="SOLR_ADMIN_DIGEST_PASSWORD" \
    -e ZOO_DIGEST_USERNAME="solr" \
    -e ZOO_DIGEST_PASSWORD="ZOO_DIGEST_PASSWORD" \
    -e ZOO_DIGEST_READONLY_USERNAME="readonly-user" \
    -e ZOO_DIGEST_READONLY_PASSWORD="ZOO_DIGEST_READONLY_PASSWORD" \
    -e SECURITY_JSON="SECURITY_JSON" \
    -e SOLR_ZOO_SSL_CONNECTION=true \
    -e SSL_PRIVATE_KEY="SSL_PRIVATE_KEY" \
    -e SSL_CERTIFICATE="SSL_CERTIFICATE" \
    -e SSL_CA_CERTIFICATE="SSL_CA_CERTIFICATE" \
    "solr_redhat" "$@"
```

For an example of the `docker run` command, see `runSolrClientCommand` function in `clientFunctions.sh` script.
For an example of how to use `runSolrClientCommand` function, see [runSolrClientCommand](../tools%20and%20functions/client_functions.md#runsolrclientcommand).

## <a name="bindmounts"></a> Bind mounts

**Secrets**:  
A directory that contains all of the secrets that this tool requires. Specifically this includes credentials to access zookeeper and certificates used in SSL.  
The directory is mounted to a location in the container defined by the `CONTAINER_SECRETS_DIR` environment variable. This can then be used by other environment variables such as `ZOO_DIGEST_USERNAME_FILE` to locate the secrets. 
In a production environment, the orchestration environment can provide the secrets to the file system or the secrets can be passed in via environment variables. The mechanism that is used here simulates the orchestration system providing the secrets as files. This is achieved by using a bind mount. In production this would not be required.

**Configuration**:  
The Solr client requires the i2 Analyze configuration to perform some Solr operations. To access the configuration, the `configuration` directory must be mounted into the container. 

## <a name="environmentvariables"></a> Environment variables

To configure the Solr client, you can provide environment variables to the Docker container in the `docker run` command.

| Environment variable           | Description |
| ------------------------------ |------------ |
| `SOLR_ADMIN_DIGEST_USERNAME`   | For usage see [Command Parsing](#commandparsing)|
| `SOLR_ADMIN_DIGEST_PASSWORD`   | For usage see [Command Parsing](#commandparsing)|
| `ZOO_DIGEST_USERNAME`          | The ZooKeeper administrator user name. This environment variable maps to the `zkDigestUsername` system property. |
| `ZOO_DIGEST_PASSWORD`          | The ZooKeeper administrator password. This environment variable maps to the `zkDigestPassword` system property. |
| `ZOO_DIGEST_READONLY_USERNAME` | The ZooKeeper read-only user name. This environment variable maps to the `zkDigestReadonlyUsername` system property. |
| `ZOO_DIGEST_READONLY_PASSWORD` | The ZooKeeper read-only password. This environment variable maps to the `zkDigestReadonlyPassword` system property. |
| `SECURITY_JSON`                | The Solr security.json. [Solr Basic Authentication](../security%20and%20users/security.md#solrbasicauthentication) |
| `SOLR_ZOO_SSL_CONNECTION`      | See [Secure Environment Variables](../security%20and%20users/security.md#secureenvironmentvariables).|
| `SERVER_SSL`                   | See [Secure Environment Variables](../security%20and%20users/security.md#secureenvironmentvariables).|
| `SSL_PRIVATE_KEY`              | See [Secure Environment Variables](../security%20and%20users/security.md#secureenvironmentvariables).| 
| `SSL_CERTIFICATE`              | See [Secure Environment Variables](../security%20and%20users/security.md#secureenvironmentvariables).|
| `SSL_CA_CERTIFICATE`           | See [Secure Environment Variables](../security%20and%20users/security.md#secureenvironmentvariables).| 

## <a name="commandparsing"></a> Command parsing

When commands are passed to the Solr client by using the `"$@"` notation, the command that is passed to the container must be escaped correctly. On the container, the command is run using `docker exec "$@"`. Because the command is passed to the `docker run` command using `bash -c`, the command must be maintained as a double quoted string.

For example:
```bash
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" 
   --cacert ${CONTAINER_SECRETS_DIR}/CA.cer 
   \"${SOLR1_BASE_URL}/solr/main_index/update?commit=true\" 
   -H Content-Type:text/xml --data-binary \"<delete><query>*:*</query></delete>\""
```

Different parts of the command must be escaped in different ways:
- `\"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\"`  
   Because the curl command uses the container's local environment variables to obtain the values of `SOLR_ADMIN_DIGEST_USERNAME` and `SOLR_ADMIN_DIGEST_PASSWORD`, the `$` is escaped by a `\`.  
   The `"` around both of the variables are escaped with a `\` to prevent the splitting of the command, which means that the variables are evaluated in the container's environment.

- `\"${SOLR1_BASE_URL}/solr/main_index/update?commit=true\"`  
   The URL is surrounded in `"` because the string contains a variable. The `"` are escaped with a `\`.  
   Because the `SOLR1_FQDN` variable is evaluated before it is passed to the container, the `$` is not escaped.  

- `\"<delete><query>*:*</query></delete>\"`  
   The data portion of the curl command is escaped with `"` because it contains special characters. The `"` are escaped with a `\`.
