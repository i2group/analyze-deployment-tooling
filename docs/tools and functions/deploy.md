# Deploy and start i2 Analyze
This topic describes how to deploy and start i2 Analyze in a containerized environment.

For an example of the activities described, see the [deploy.sh](../../environments/pre-prod/deploy.sh)

## Running Solr and ZooKeeper
The running Solr and ZooKeeper section runs the required containers and creates the Solr cluster and ZooKeeper ensemble.

### Create Solr cluster
The `createSecureCluster` function creates the secure Solr cluster for the deployment. The function includes a number of calls that complete the following actions:

1. The `runZK` server function runs the ZooKeeper containers that make up the ZooKeeper ensemble. For more information about running a ZooKeeper container, see [ZooKeeper](../images and containers/zookeeper.md). 
   In `deploy.sh`, 3 ZooKeeper containers are used.

1. The `runSolrClientCommand` client function is used a number of times to complete the following actions:
   1. Create the `znode` for the cluster.  
    i2 Analyze uses a ZooKeeper connection string with a chroot. To use a chroot connection string, a *znode* with that name must exist. For more information, see [SolrCloud Mode](https://lucene.apache.org/solr/guide/8_6/solr-control-script-reference.html#solrcloud-mode).
    1. Set the `urlScheme` to be `https`.
    1. Configure the Solr authentication by uploading the `security.json` file to ZooKeeper.
  
   For more information about the function, see [runSolrClientCommand](./client_functions.md#runsolrclientcommand).
    
1. The `runSolr` server function runs the Solr containers for the Solr cluster. For more information about running a Solr container, see [Solr](../images%20and%20containers/solr.md).  
   In `deploy.sh`, 2 Solr containers are used.

At this point, your ZooKeepers are running in an ensemble, and your Solr containers are running in SolrCloud Mode managed by ZooKeeper.

## Initializing the Information Store database 
The initializing the Information Store database section runs the database container and configures the database management system.

### Running the database server container
The `runSQLServer` server function creates the secure SQL Server container for the deployment.

For more information about building the SQL Server image and running a container, see [Microsoft SQL Server](../images%20and%20containers/sql_server.md).

Before continuing, `deploy.sh` uses the `waitForSolrToBeLive` and `waitForSQLServerToBeLive` client functions to ensure that Solr and SQL Server are running. For more information, see [Status utilities](./client_functions.md#status-utilities)

### Configuring SQL Server
The `configureSecureSqlServer` function uses a number of client and server functions to complete the following actions:

1. The `changeSAPassword` client function is used to change the `sa` user's password.  
  For more information, see [changeSAPassword](../security%20and%20users/db_users.md#changing-sa-password)

1. Generate the static Information Store database scripts.
   * The `runi2AnalyzeTool` client function is used to run the `generateStaticInfoStoreCreationScripts.sh` tool.  
      * [runi2AnalyzeTool](./client_functions.md#runi2analyzetool)
      * [Generate static database scripts tool](./i2analyze_tools.md#generate-static-database-scripts-tool)

1. Create the Information Store database and schemas.
   * The `runSQLServerCommandAsSA` client function is used to run the `runDatabaseCreationScripts.sh` tool.  
      * [runSQLServerCommandAsSA](./client_functions.md#runsqlservercommandassa)
      * [runDatabaseCreationScripts.sh]()

1. Create the database roles, logins, and users.  
For more information about the database users and their permissions, see [Database users](../security%20and%20users/db_users.md).
   1. The `runSQLServerCommandAsSA` client function runs the `createDbRoles.sh` script.
   1. The `createDbLoginAndUser` client function creates the logins and users.
   1. The `runSQLServerCommandAsSA` client function runs the `addEtlUserToSysAdminRole.sh` script.

1. Run the static scripts that create the Information Store database objects.
   * The `runSQLServerCommandAsSA` client function is used to run the `runStaticScripts.sh` tool.  
      * [runSQLServerCommandAsSA](./client_functions.md#runsqlservercommandassa)
      * [Run static database scripts tool](./i2analyze_tools.md#run-static-database-scripts-tool)

## Configuring Solr and ZooKeeper
The configuring Solr and ZooKeeper sections configures the Solr cluster and creates the Solr collections.

1. The `configureSecureSolr` function uses the `runSolrClientCommand` client function to upload the `managed-schema`, `solr.xml`, and synonyms file for each collection to ZooKeeper.  
   For example: 
   ```bash
   runSolrClientCommand solr zk upconfig -v -z "${ZK_HOST}" -n daod_index -d /conf/solr_config/daod_index
   ```

1. The `setClusterPolicyForSecureSolr` function uses the `runSolrClientCommand` client function to set a cluster policy such that each host has 1 replica of each shard.  
   For example:
   ```bash
   runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\"
   --cacert ${CONTAINER_SECRETS_DIR}/CA.cer -X POST -H Content-Type:text/xml -d 
   '{ \"set-cluster-policy\": [ {\"replica\": \"<2\", \"shard\": \"#EACH\", \"host\": \"#EACH\"}]}' 
   \"${SOLR1_BASE_URL}/api/cluster/autoscaling\""
   ```

   For more information about Solr policies, see [Autoscaling Policy and Preferences](https://lucene.apache.org/solr/guide/8_6/solrcloud-autoscaling-policy-preferences.html#policy-specification).

1. The `createCollectionForSecureSolr` function uses the `runSolrClientCommand` client function to create each Solr collection.  
   For example:
   ```bash
   runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\"
   --cacert ${CONTAINER_SECRETS_DIR}/CA.cer 
   \"${SOLR1_BASE_URL}/solr/admin/collections?action=CREATE&name=main_index&collection.configName=main_index&numShards=1&maxShardsPerNode=4&rule=replica:<2,host:*\""
   ```
   For more information about the Solr collection API call, see [CREATE: Create a Collection](https://lucene.apache.org/solr/guide/8_6/collection-management.html#create).

## Configuring the Information Store database
The configuring the Information Store database section creates objects within in the database.

1. Generate the dynamic database scripts that create the schema specific database objects.
   * The `runi2AnalyzeTool` client function is used to run the `generateDynamicInfoStoreCreationScripts.sh` tool.
      * [runi2AnalyzeTool](./client_functions.md#runi2analyzetool)
      * [Generate dynamic Information Store creation scripts tool](./i2analyze_tools.md#generate-dynamic-information-store-creation-scripts-tool)
1. Run the generated dynamic database scripts.
   * The `runSQLServerCommandAsSA` client function is used to run the `runDynamicScripts.sh` tool.
      * [runSQLServerCommandAsSA](./client_functions.md#runsqlservercommandassa)
      * [Run dynamic Information Store creation scripts tool](./i2analyze_tools.md#run-dynamic-information-store-creation-scripts-tool)

## Configuring the Example Connector
The configuring example connector section runs the example connector used by the i2 Analyze application.

1. The `runExampleConnector` server function runs the example connector application.

1. The `waitForConnectorToBeLive` client function checks the connector is live before allowing the script to proceed.

## Configuring i2 Analyze 
The configuring i2 Analyze section runs the Liberty containers that run the i2 Analyze application.

1. The `buildLibertyConfiguredImage` server function builds the configured Liberty image.  For more information, see [Building a configured Liberty image](../images%20and%20containers/liberty.md#building-a-configured-liberty-image).

1. The `runLiberty` server function runs a Liberty container from the configured image.  
For more information, see [Running a Liberty container](../images%20and%20containers/liberty.md#running-a-liberty-container)
   In `deploy.sh`, 2 liberty containers are used.

1. Starting the load balancer.  
   The `runLoadBalancer` functions in `serverFunctions.sh` runs HAProxy as a load balancer in a Docker container.  
   The load balancer configuration is in the `haproxy.cfg` file. The load balancer routes requests to the application to both Liberty servers that are running.  
   The configuration that used is a simplified configuration for example purposes and is not to be used in production. 

   For more information about configuring a load balancer with i2 Analyze, see [Load balancer](https://www.ibm.com/support/knowledgecenter/SSXVXZ_latest/com.ibm.i2.deploy.example.doc/hadr_loadbalancer.html).

1. Before continuing, `deploy.sh` uses the `waitFori2AnalyzeServiceToBeLive` client function to ensure that Liberty is running. For more information, see [Status utilities](./client_functions.md#status-utilities)

1. Deploy the system match rules.
   * The `runSolrClientCommand` client function is used to run the `runIndexCommand.sh` tool. The tool is run twice, once to update the match rules file and once to switch the match indexes.  
   For more information, see [Manage Solr indexes tool](./i2analyze_tools.md#manage-solr-indexes-tool).