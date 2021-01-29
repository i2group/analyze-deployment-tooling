# Failure of the Solr cluster
This section demonstrates how a deployment of i2 Analyze responds to the failure of all Solr nodes. This section also describes how to monitor and detect failure and ensure the recovery was successful.

Before you begin the walkthrough, there a number of concepts that it is useful to understand:
* How Solr is deployed for high availability. For more information, see [Solr](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/solr_co.html).
* How the Solr status is reported in the component availability log in Liberty. For more information, see [Monitor the system availability](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/ha_monitoring.html).
* In a containerised deployment, all log messages are also displayed in the console. You can use the `docker logs` command to view the console log.

The `solrClusterFailureWalkthrough.sh` scripts simulates a Solr cluster failure and recovery.

## Simulating Solr Cluster failure

To simulate the cluster failure, remove all the Solr containers. For example, run:

```DOCKER
docker stop solr2 solr1
```

See the `Simulating the cluster failure` section of the walkthrough script.

## Detecting failure
The component availability log in Liberty is used to monitor and determine the status of the Solr cluster.

When the Solr cluster is unavailable, the status is reported as `DOWN`.

The `detecting failure` section of the walkthrough script runs a loop around the `getSolrStatus` client function that reports the status of Solr. For more information about the function, see [`getSolrStatus`](../tools%20and%20functions/client_functions.md#getsolrstatus).

The function uses a grep command for the following message that indicates Solr is down:

```Bash
grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DOWN'"
```

## Reinstating high availability
To reinstate high availability, restart the failed Solr containers. In this example, restart both Solr containers by running the following command:
```DOCKER
docker start solr2 solr1
```

After the failed nodes recover, Liberty reports the changes to the cluster status. To ensure the collections recover, monitor the Liberty logs for healthy collections.

The `reinstating high availability` section of the walkthrough script runs a loop around the `getSolrStatus` client function that reports the status of Solr. For more information about the function, see [`getSolrStatus`](../tools%20and%20functions/client_functions.md#getsolrstatus).

The function uses a grep command for the following message that indicates Solr is active:

```Bash
grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'ALL_REPLICAS_ACTIVE'"
```
