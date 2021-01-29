# Adding a new Solr node

This section describes an example of the process of adding a new Solr Node to an existing Solr cluster and using the Solr Collections API to add a replica on the newly created Solr node.

You can use `addSolrNodeWalkthrough.sh` script to add a Solr node to the example deployment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](./reset_walkthroughs.md).

## <a name="runninganewsolrcontainer"></a> Running a new Solr container

To add a Solr node to an existing Solr collection in the Docker environment, you run a new Solr container.
See the `Running a new Solr container` section of the walkthrough script. 

The `runSolr` server function in the `addSolrNodeWalkthrough.sh` is used to run a new Solr container with a node that is added to the existing cluster.

For more information about running a Solr container, see [Solr](../images%20and%20containers/solr.md#runningasolrcontainer).

The following environment variables are used to specify the hostname of the container and to add the node to the existing cluster:
- `SOLR_HOST` specifies the fully qualified domain name of the Solr container.
- `ZK_HOST` Specifies the connection string for each ZooKeeper server to connect to. To connect to more than one ZooKeeper server, the values must be in comma separated list. When the connection string connects to the existing ZooKeeper quorum, the new Solr node is automatically added to the Solr cluster.

## <a name="addingasolrreplica"></a> Adding a Solr replica

To use the new Solr node, you must add a replica for a shard and create it on the new Solr node.
See the `Adding a Solr replica` section of the walkthrough script. 

To add a replica, use the Solr Collections API. For more information about the API command, see [ADDREPLICA: Add Replica](https://lucene.apache.org/solr/guide/8_6/replica-management.html#replica-management)

The following curl command is an example that creates a replica for shard1 in the main_index collection on the new Solr node:

```sh
curl -u "${SOLR_ADMIN_DIGEST_USERNAME}":"${SOLR_ADMIN_DIGEST_PASSWORD}"
 --cacert /CA/CA.cer
 "${SOLR1_BASE_URL}/solr/admin/collections?action=ADDREPLICA&collection=main_index&shard=shard1&node=${SOLR3_FQDN}:8983_solr"
```

In the `addSolrNodeWalkthrough.sh` script, the `runSolrClientCommand` function contains an example of how to run the curl command in a containerized environment:

```sh
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert ${CONTAINER_SECRETS_DIR}/CA.cer \"${SOLR1_BASE_URL}/solr/admin/collections?action=ADDREPLICA&collection=main_index&shard=shard1&node=${SOLR3_FQDN}:8983_solr\""
```

For more information about command parsing, see [Command parsing](../images%20and%20containers/solr_client.md#commandparsing)

The example above uses `${SOLR3_FQDN}`, but you can use the fully qualified domain name of any Solr node in the cluster.
