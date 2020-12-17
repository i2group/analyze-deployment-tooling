# Updating the security schema

This section describes an example of the process to update the security schema of a deployment in a Docker environment. To update the security schema in a deployment, you need to update the Information Store database and restart the application server.

Updating the security schema includes the following high-level steps:

* Removing Liberty containers
* Modifying the security schema file
* Starting Liberty containers
    * When you start Liberty, the security schema that it caches from the database is updated
* Updating the Information Store
* Running the Liberty containers
* Validating database consistency

The `updateSecuritySchemaWalkthrough.sh` script is a worked example that demonstrates how to update the security schema in a containerized environment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](../reset_walkthroughs.md).

## Removing the Liberty containers

Before you update the security schema in the Information Store, you remove the Liberty containers. To do remove the containers, run the following docker commands:

```bash
docker stop liberty1 liberty2
docker rm liberty1 liberty2
```

See the `Removing the Liberty containers` section of the walkthrough script.

## Modifying your security schema

In the `updateSecuritySchemaWalkthrough.sh` script, the `updateSecuritySchemaFile` function copies a modified `security-schema.xml` from the `walkthrouhgs/configuration-changes` directory to the `configuration/fragments/common/WEB-INF/classes/` directory.
For more information about the structure of the security schema, see [The i2 Analyze security schema](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.eia.go.live.doc/c_sec_schema.html).

The `buildLibertyConfiguredImage` server function builds the configured Liberty image.  For more information, see [Building a configured Liberty image](../images%20and%20containers/liberty.md#building-a-configured-liberty-image).
See the `Modifying the security schema` section of the walkthrough script.

## Validating your schema

After you modify the security schema, you can use the `validateSchemaAndSecuritySchema.sh` tool to validate it. If the security schema is invalid, errors are reported.
See the `Validating the new security` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `validateSchemaAndSecuritySchema.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [validateSchemaAndSecuritySchema](../tools%20and%20functions/i2analyze_tools.md#schema-validation-tool)

## Updating the Information Store

See the `Updating the Information Store` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `updateSecuritySchema.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [updateSecuritySchema](../tools%20and%20functions/i2analyze_tools.md#security-schema-update-tool)

## Running the Liberty containers

The `runLiberty` server function runs a Liberty container. For more information about running a Liberty container, see [Liberty](../images%20and%20containers/liberty.md).  
See the `Running the Liberty containers` section of the walkthrough script.

> Note: You must run both Liberty containers.

The `waitFori2AnalyzeServiceToBeLive` client function ensures that Liberty is running. For more information, see [Status utilities](../tools%20and%20functions/client_functions.md#status-utilities#waitFori2AnalyzeServiceToBeLive).

## Validating database consistency

After the system has started, the `dbConsistencyCheckScript.sh` tool is used to check the state of the database after the Information Store tables are modified.
See the `Validating database consistency` section of the walkthrough script.

The `runi2AnalyzeTool` client function is used to run the `dbConsistencyCheckScript.sh` tool.  
  * [runi2AnalyzeTool](../tools%20and%20functions/client_functions.md#runi2analyzetool)
  * [dbConsistencyCheckScript](../tools%20and%20functions/i2analyze_tools.md#information-store-database-consistency-tool)