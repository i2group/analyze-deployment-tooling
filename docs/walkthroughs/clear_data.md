# Clearing data from a deployment

This section describes an example of the process to clear the data from your deployment in a Docker environment.

Clearing the data from a deployment includes the following high-level steps:
* Removing the Liberty containers
* Clearing the search index
  * Creating and running a delete query
  * Removing the collection properties
* Clearing data from the Information Store
* Remove all of the data in the Information Store
* Running the Liberty containers

The `clearDataWalkthrough.sh` script is a worked example that demonstrates how to clear the data from the Information Store in a containerized environment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](../reset_walkthroughs.md).

## Removing the Liberty containers

Before you clear the data from a deployment, you remove the Liberty containers. To do remove the containers, run the following docker commands:

```bash
docker stop liberty1 liberty2
docker rm liberty1 liberty2
```

See the `Removing the Liberty containers` section of the walkthrough script.

## Clearing the search index

### Creating and running a delete query

To clear the search index, run a Solr delete query against your indexes via the Solr API. 
You can run the delete query by using a curl command. In Solr, data is stored as documents. 
You must remove every document from each collection in your deployment.
The `runSolrClientCommand` client function is used to run the curl commands that remove the documents from each collection. 
For more information about the function, see [runSolrClientCommand](../tools%20and%20functions/client_functions.md#runsolrclientcommand).

The following curl command removes every document from a the `main_index`:

```bash
curl -u "${SOLR_ADMIN_DIGEST_USERNAME}:${SOLR_ADMIN_DIGEST_PASSWORD}" --cacert ${CONTAINER_SECRETS_DIR}/CA.cer "${SOLR1_BASE_URL}/solr/main_index/update?commit=true" -H Content-Type:"text/xml" --data-binary "<delete><query>*:*</query></delete>"
```

See the `Clearing the search index` section of the walkthrough script.

For more information about command parsing, see [Command parsing](../images%20and%20containers/solr_client.md#Command_parsing)

### Removing the collection properties

The `runSolrClientCommand` client function is used to remove the file from ZooKeeper. 
For more information about the function, see [runSolrClientCommand](../tools%20and%20functions/client_functions.md#runsolrclientcommand).

The following `zkcli` call removes the collection properties for the `main_index`.
```bash
zkcli.sh -zkhost "${ZK_HOST}" -cmd clear "/collections/main_index/collectionprops.json"
```

See the `Clearing the search index` section of the walkthrough script.

The collection properties must be removed for any main, match, or chart collections.

The `collectionprops.json` file is recreated when the i2 Analyze application is started. 

## Clearing data from the Information Store

See the `Clearing the Information Store database` section of the walkthrough script.

The `runSQLServerCommandAsDBA` client function is used to run the `clearInfoStoreData.sh` tool to remove the data from the Information Store.  
  * [runSQLServerCommandAsDBA](../tools%20and%20functions/client_functions.md#runsqlservercommandasdba)
  * [clearInfoStoreData](../tools%20and%20functions/i2analyze_tools.md#remove-data-from-the-information-store-tool)
  
## Running the Liberty containers

The `runLiberty` server function runs a Liberty container. For more information about running a Liberty container, see [Liberty](../images%20and%20containers/liberty.md#Running_a_Liberty_container).
See the `Running the Liberty containers` section of the walkthrough script.

> Note: You must run both Liberty containers.

The `waitFori2AnalyzeServiceToBeLive` client function ensures that Liberty is running. For more information, see [Status utilities](../tools%20and%20functions/client_functions.md#status-utilities#waitFori2AnalyzeServiceToBeLive).