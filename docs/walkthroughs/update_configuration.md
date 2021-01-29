# Updating the i2 Analyze application configuration

This section describes an example of the process to update the configuration of a deployment in a Docker environment. After you update the configuration, rebuild the configured Liberty image. You must rebuild the image, because the configuration is part of the image.

Updating the configuration includes the following high-level steps:

* Removing Liberty containers
* Updating configuration
* Rebuilding the configured Liberty image with the modified configuration
* Running the Liberty containers
    * When you start Liberty, the schema that it caches from the database is updated

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](./reset_walkthroughs.md).

## <a name="removingthelibertycontainers"></a> Removing the Liberty containers

Before you update the application configuration, you remove the Liberty containers. To do remove the containers, run the following docker commands:

```bash
docker stop liberty1 liberty2
docker rm liberty1 liberty2
```

See the `Removing the Liberty containers` section of the walkthrough script.

## <a name="updatingyourconfiguration"></a> Updating your configuration

In the `updateConfigurationWalkthrough.sh` script, a modified `geospatial-configuration.xml` is being copied from the `/walkthrouhgs/configuration-changes` directory to the `configuration/fragments/common/WEB-INF/classes/` directory.

For information about modifying the configuration, see [Configuring the i2 Analyze application](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/eia_going_live.html).

See the `Updating the configuration` section of the walkthrough script.

After you modify the configuration, build a new configured liberty image with the updated configuration.

The `buildLibertyConfiguredImage` server function builds the configured Liberty image.  For more information, see [Building a configured Liberty image](../images%20and%20containers/liberty.md#buildingaconfiguredlibertyimage).

### <a name="runningthelibertycontainers"></a> Running the Liberty containers

The `runLiberty` server function runs a Liberty container. For more information about running a Liberty container, see [Liberty](../images%20and%20containers/liberty.md).  
See the `Running the Liberty containers` section of the walkthrough script.

> Note: You must run both Liberty containers.

The `waitFori2AnalyzeServiceToBeLive` client function ensures that Liberty is running. For more information, see [Status utilities](../tools%20and%20functions/client_functions.md#status-utilities#waitFori2AnalyzeServiceToBeLive).