# Updating the schema

This section describes an example of the process to update the schema of a deployment in a Docker environment. To update the schema in a deployment, you need to update the Information Store database and restart the application server.

Updating the schema includes the following high-level steps: 

* Removing Liberty containers
* Modifying the schema file
* Generating the database scripts to update the Information Store database
* Running the generated scripts against your Information Store database
* Running Liberty containers
    * When you start Liberty, the schema that it caches from the database is updated
* Validating database consistency

The `updateSchemaWalkthrough.sh` script is a worked example that demonstrates how to update the schema in a containerized environment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](./reset_walkthroughs.md).

## <a name="removingthelibertycontainers"></a> Removing the Liberty containers

Before you update the schema in the Information Store, you remove the Liberty containers. To remove the containers, run the following docker commands:

```bash
docker stop liberty1 liberty2
docker rm liberty1 liberty2
```

See the `Removing the Liberty containers` section of the walkthrough script.

## <a name="modifyingyourschema"></a> Modifying your schema

In the `updateSchemaWalkthrough.sh` script, a modified `schema.xml` from the `walkthrouhgs/configuration-changes` directory is copied to the `configuration/fragments/common/WEB-INF/classes/` directory.
After you modify the configuration, build a new configured liberty image with the updated configuration.
The `buildLibertyConfiguredImage` server function builds the configured Liberty image.  For more information, see [Building a configured Liberty image](../images%20and%20containers/liberty.md#buildingaconfiguredlibertyimage).
See the `Modifying the schema` section of the walkthrough script.

To modify your schema, use IBM i2 Analyze Schema Designer. For more information on installing Schema Designer please see: [IBM i2 Analyze Schema Designer](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.schemadesigner.doc/ar_tools_welcome.html).

## <a name="validatingyourschema"></a> Validating your schema

After you modify the schema, you can use the `validateSchemaAndSecuritySchema.sh` tool to validate it. If the schema is invalid, errors are reported.
See the `Validating the schema` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `validateSchemaAndSecuritySchema.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [validateSchemaAndSecuritySchema](../tools%20and%20functions/i2analyze_tools.md#schemavalidationtool)

## <a name="generatingthedatabasescripts"></a> Generating the database scripts

After you modify and validate the schema, generate the database scripts that are used to update the Information Store database to reflect the change.
See the `Generating update schema scripts` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `generateUpdateSchemaScripts.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [generateUpdateSchemaScripts](../tools%20and%20functions/i2analyze_tools.md#schemaupdatetool)

## <a name="runningthegeneratedscripts"></a> Running the generated scripts

After you generate the scripts, run them against the Information Store database to update the database objects to represent the changes to the schema.
See the `Running the generated scripts` section of the walkthrough script.

The `runSQLServerCommandAsDBA` client function is used to run the `runDatabaseScripts.sh` tool.  
  * [runSQLServerCommandAsDBA](../tools%20and%20functions/client_functions.md#runSQLServerCommandAsDBA)
  * [runDatabaseScripts](../tools%20and%20functions/i2analyze_tools.md#rundatabasescriptstool)

After the database scripts are run, the Information Store database is updated with any changes to the schema.

## <a name="runningthelibertycontainers"></a> Running the Liberty containers

The `runLiberty` server function runs a Liberty container. For more information about running a Liberty container, see [Liberty](../images%20and%20containers/liberty.md).  
See the `Running the Liberty containers` section of the walkthrough script.

> Note: You must run both Liberty containers.

The `waitFori2AnalyzeServiceToBeLive` client function ensures that Liberty is running. For more information, see [Status utilities](../tools%20and%20functions/client_functions.md#status-utilities#waitFori2AnalyzeServiceToBeLive).

## <a name="validatingdatabaseconsistency"></a> Validating database consistency

After the system has started, the `dbConsistencyCheckScript.sh` tool is used to check the state of the database after the Information Store tables are modified.
See the `Validating database consistency` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `dbConsistencyCheckScript.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [dbConsistencyCheckScript](../tools%20and%20functions/i2analyze_tools.md#informationstoredatabaseconsistencytool)
