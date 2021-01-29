# <a name="clientutilities"></a> Client utilities
The `clientFunctions.sh` file contains functions that you can use to perform actions against the server components of i2 Analyze.

## <a name="secretsutilities"></a> Secrets utilities
The `getSecret` function gets a secret such as a password for a user.
For more info see [secrets-files](../security%20and%20users/security.md#secrets-files)

## <a name="statusutilities"></a> Status utilities
The status utilities report whether a component of i2 Analyze is live.

### <a name="waitforindexestobebuilt"></a> waitForIndexesToBeBuilt
The `waitForIndexesToBeBuilt` function sends a request to the `admin/indexes/status` endpoint. If the response indicates no indexes are still `BUILDING` the function returns and prints a message to indicate the indexes have been built.
If the indexes are not all built after 5 retries the function will print an error and exit.

### <a name="waitforconnectortobelive"></a> waitForConnectorToBeLive
This function takes (1) the fully qualified domain name of a connector and (2) the port of the connector as its arguments.
The `waitForConnectorToBeLive` function sends a request to the connector's`/config` endpoint. If the response is `200`, the connector is live. If the connector is not live after 50 tires the function will print an error and exit.

### <a name="getsolrstatus"></a> getSolrStatus
This function takes (1) a timestamp that is used to specify the point in the logs after which the logs are monitored.  

The `getSolrStatus` function used the logs from the Liberty container, and uses a grep command to find specific component availability messages. The function returns the entries in the logs that match message in the grep command.  
If no matching message is found, the function prints the following error and exits:  

```"No response was found from the component availability log (attempt: ${i}). Waiting..."```

## <a name="databasesecurityutilities"></a> Database Security Utilities

### <a name="changesapassword"></a> changeSAPassword
The `changeSAPassword` function uses the generated secrets to call the `changeSAPassword.sh` with the initial (generated) sa password and the new (generated) password.

### <a name="createdbloginanduser"></a> createDbLoginAndUser
The `createDbLoginAndUser` function takes a `user` and a `role` as its arguments.
The function creates a database login and user for the provided `user`, and assigns the user to the provided `role`.

## <a name="executionutilities"></a> Execution utilities
The execution utilities enable you to run commands and tools from client containers against the server components of i2 Analyze.

### <a name="runsolrclientcommand"></a> runSolrClientCommand
The `runSolrClientCommand` function uses an ephemeral Solr client container to run commands against Solr.

For more information about the environment variables and volume mounts that are required for the Solr client, see [Running a Solr client container](../images%20and%20containers/solr_client.md).

The `runSolrClientCommand` function takes the command you want to run as an argument. For example:
```bash
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
```
For more information about commands you can execute using the Solr `zkcli`, see [Solr ZK Command Line Utilities](https://lucene.apache.org/solr/guide/8_6/command-line-utilities.html)

### <a name="runi2analyzetool"></a> runi2AnalyzeTool
The `runi2AnalyzeTool` function uses an ephemeral i2 Analyze Tool container to run the i2 Analyze tools.

For more information about the environment variables and volume mounts that are requires for the i2Analyze tool, see [Running an i2 Analyze Tool container](../images%20and%20containers/i2analyze_tool.md)

The `runi2AnalyzeTool` function takes the i2 tool you want to run as an argument. For example:
```bash
runi2AnalyzeTool "/opt/i2-tools/scripts/updateSecuritySchema.sh"
```

### <a name="runi2analyzeservicerequest"></a> runi2AnalyzeToolAsExternalUser
The `runi2AnalyzeToolAsExternalUser` function uses an ephemeral i2 Analyze Tool container to run commands against the i2 Analyze service via the load balancer as an external user. 

The container contains the required secrets to communicate with the i2 Analyze service from an external container. 

For example, if you would like to send a Curl request to the load balancer stats endpoint, run:
```sh
runi2AnalyzeToolAsExternalUser bash -c "curl \
        --silent \
        --cookie-jar /tmp/cookie.txt \
        --cacert /tmp/i2acerts/CA.cer \
        --request POST \"${FRONT_END_URI}/j_security_check\" \
        --header 'Origin: ${FRONT_END_URI}' \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'j_username=Jenny' \
        --data-urlencode 'j_password=Jenny' \
      && curl \
        --silent \
        --cookie /tmp/cookie.txt \
        --cacert /tmp/i2acerts/CA.cer\
        \"${FRONT_END_URI}/api/v1/admin/indexes/status\""
```

### <a name="runsqlservercommandasetl"></a> runSQLServerCommandAsETL
The `runSQLServerCommandAsETL` function uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the `etl` user.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `runSQLServerCommandAsETL` function takes the database script or commands that you want to run as an argument. For example:

```bash
runSQLServerCommandAsETL bash -c "/opt/mssql-tools/bin/sqlcmd -N -b -S \${DB_SERVER} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} -Q 
\"BULK INSERT IS_Staging.E_Person 
FROM '/tmp/examples/data/law-enforcement-data-set-2-merge/person.csv' 
WITH (FORMATFILE = '/tmp/examples/data/law-enforcement-data-set-2-merge/sqlserver/format-files/person.fmt', FIRSTROW = 2)\""
```

### <a name="runsqlservercommandasi2etl"></a> runSQLServerCommandAsi2ETL
The `runSQLServerCommandAsi2ETL` function uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the `i2etl` user, such as executing generated drop/create index scripts, created by the ETL toolkit.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `runSQLServerCommandAsi2ETL` function takes the database script or commands that you want to run as an argument. For example:

```bash
runSQLServerCommandAsi2ETL bash -c "${SQLCMD} ${SQLCMD_FLAGS} \
  -S \${DB_SERVER},${DB_PORT} -U \${DB_USERNAME} -P \${DB_PASSWORD} -d \${DB_NAME} \
  -i /opt/database-scripts/ET5-drop-entity-indexes.sql"
```

### <a name="runsqlservercommandasfirststartsa"></a> runSQLServerCommandAsFirstStartSA
The `runSQLServerCommandAsFirstStartSA` function uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the `sa` user with the initial SA password.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

### <a name="runsqlservercommandassa"></a> runSQLServerCommandAsSA
The `runSQLServerCommandAsSA` function uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the `sa` user.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `runSQLServerCommandAsSA` function takes the database script or commands that you want to run as an argument. For example:

```bash
runSQLServerCommandAsSA "/opt/i2-tools/scripts/database-creation/runStaticScripts.sh"
```

### <a name="runsqlservercommandasdba"></a> runSQLServerCommandAsDBA
The `runSQLServerCommandAsDBA` function uses an ephemeral SQL Client container to run database scripts or commands against the Information Store database as the `dba` user.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `runSQLServerCommandAsDBA` function takes the database script or commands that you want to run as an argument. For example:

```bash
runSQLServerCommandAsDBA "/opt/i2-tools/scripts/clearInfoStoreData.sh"
```

### <a name="runetltoolkittoolasi2etl"></a> runEtlToolkitToolAsi2ETL
The `runEtlToolkitToolAsi2ETL` function uses an ephemeral ETL toolkit container to run ETL toolkit tasks against the Information Store using the i2 ETL user credentials.

For more information about running the ETL Client container and the environment variables required for the container, see [ETL Client](../images%20and%20containers/etl_client.md).

For more information about running the ETL toolkit container and the tasks that you can run, see [ETL](./etl_tools.md)

The `runEtlToolkitToolAsi2ETL` function takes command that you want to run as an argument. For example:
```bash
runEtlToolkitToolAsi2ETL bash -c "/opt/ibm/etltoolkit/addInformationStoreIngestionSource --ingestionSourceName EXAMPLE_1 --ingestionSourceDescription EXAMPLE_1"
```

### <a name="runetltoolkittoolasdba"></a> runEtlToolkitToolAsDBA
Some ETL tasks must be performed by the DBA. The `runEtlToolkitToolAsDBA` function used the same ephemeral ETL toolkit container but uses the DBA user instead of the ETL user.

For more information about running the ETL Client container and the environment variables required for the container, see [ETL Client](../images%20and%20containers/etl_client.md).

For more information about running the ETL toolkit container and the tasks that you can run, see [ETL](./etl_tools.md)

The `runEtlToolkitToolAsDBA` function takes command that you want to run as an argument. For example:
```bash
runEtlToolkitToolAsDBA bash -c "/opt/ibm/etltoolkit/enableMergedPropertyValues --schemaTypeId ET5"
```

