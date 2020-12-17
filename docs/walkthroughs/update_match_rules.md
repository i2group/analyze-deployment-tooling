# Updating the system match rules

This section describes an example of the process to update the system match rules of a deployment with the Information Store.
Updating your match rules in your deployment includes the following high-level steps after you modify your system match rules file:
* Update the match rules file
* Upload the updated system match rules file to ZooKeeper
* Create a standby match index with the new system match rules, and wait for a response from the server to say that the standby match index is ready
* Switch your standby match index to live

The `updateMatchRulesWalkthrough.sh` script is a worked example that demonstrates how to update the system match rules in a containerized environment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](../reset_walkthroughs.md).

## Updating your system match rules file

In the `updateMatchRulesWalkthrough.sh` script, the modified `system-match-rules.xml` is copied from the `environments/pre-prod/dev/walkthrouhgs/configuration-changes` directory to the `configuration/fragments/common/WEB-INF/classes/` directory.
See the `Updating system-match-rules.xml` section of the walkthrough script.

For more information about modifying the system match rules file, see [Deploying system match rules](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/creating_smr_is.html). 

## Uploading system match rules to ZooKeeper

After you modify the system match rules file, use the `update_match_rules` function of the `runIndexCommand.sh` script to upload the match rules to ZooKeeper. 
For more information, see [Manage Solr indexes tool](../tools%20and%20functions/i2analyze_tools.md#manage-solr-indexes-tool).

The `runIndexCommand` function with the `update_match_rules` argument in the `updateMatchRulesWalkthrough.sh` script contains the `docker run` command that uses an ephemeral Solr client container to upload the match rules.

To use the tool in a Docker environment, the following prerequisites must be present:

* **The Docker toolkit and your configuration must be available in the container.**
  * In the example, the toolkit and configuration are volume mounted in the `docker run` command. For example:
    ```bash
          -v "pre-reqs/i2analyze/toolkit:/opt/toolkit" \
          -v "environment/pre-prod/configuration:/opt/"
    ```

* **Environment variables**
  * The tool requires a number of environment variables to be set. For the list of environment variables that you can set, see [Manage Solr indexes tool](../tools%20and%20functions/i2analyze_tools.md#manage-solr-indexes-tool).

* **Java**
  * The container must be able to run Java executables. In the example, the container uses the `adoptopenjdk` image from DockerHub.
    ```bash
      adoptopenjdk/openjdk8:ubi-jre
    ```

## Checking the standby match index status

When uploading match rules, the `runIndexCommand.sh` will wait for 5 minutes for a response from the server. If however, it takes longer to create the new match index a curl command can be run against liberty. 

The `waitForIndexesToBeBuilt` client function makes a request to the `api/v1/admin/indexes/status` endpoint and inspects the JSON response to see if the match index is built.

## Switching the standby match index to live

After the standby index is ready, you can switch the standby index to live for resolving matches. Use the `switch_standby_match_index_to_live` function of the `runIndexCommand.sh` script to switch the indexes.

The `runIndexCommand` function with the `switch_standby_match_index_to_live` argument in the `updateMatchRulesWalkthrough.sh` script contains the `docker run` command that uses an ephemeral Solr client container to switch the match indexes.

The tool outputs a message when the action is completed successfully and exit code `0` is returned. For example:

```
> INFO  [IndexControlHelper] - The server processed the command successfully:
 > Switched the live Match index from 'match_index1' to 'match_index2'.
```

If there are any errors, the error is displayed in the console.