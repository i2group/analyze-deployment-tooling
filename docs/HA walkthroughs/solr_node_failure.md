# Failure of a Solr node

This walkthrough demonstrates losing a Solr node from a collection, and describes how to identify failure, continue operations, and reinstate high availability with your Solr nodes.

Before you begin the walkthrough, there a number of concepts that it is useful to understand:
* How Solr is deployed for high availability. For more information, see [Solr](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/solr_co.html).
* How the Solr status is reported in the component availability log in Liberty. For more information, see [Monitor the system availability](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/ha_monitoring.html).
* In a containerised deployment, all log messages are also displayed in the console. You can use the `docker logs` command to view the console log.

The `solrNodeFailureWalkthrough.sh` script demonstrates how to monitor the Liberty logs to identify Solr node failure and recovery. In the example, each shard has 2 replicas and 1 replica is located on each Solr node. This means that the Solr cluster can continue to process requests when one Solr node is taken offline.

## Simulating Solr node failure

To simulate a node failure, one of the Solr containers is stopped in the `Stop the Solr container` section.  
For example:

```DOCKER
docker stop solr2
```

See the `Simulating the cluster failure` section of the walkthrough script.

## Detecting failure
The component availability log in Liberty is used to monitor and determine the status of the Solr cluster.

When the Solr Node is unavailable, the status is reported as `DEGRADED`.

The `detecting failure` section of the walkthrough script runs a loop around the `getSolrStatus` client function that reports the status of Solr. For more information about the function, see [`getSolrStatus`](../tools%20and%20functions/client_functions.md#getsolrstatus).

The function uses a grep command for the following message that indicates Solr is down:

```Bash
grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'DEGRADED'"
```

## Reinstating high availability
To reinstate high availability, restart the failed Solr containers. In this example, restart the Solr  by running the following command:
```DOCKER
docker start solr1
```

After the failed node recovers, Liberty reports the changes to the cluster status. To ensure the collections recover, monitor the Liberty logs for healthy collections.

The `reinstating high availability` section of the walkthrough script runs a loop around the `getSolrStatus` client function that reports the status of Solr. For more information about the function, see [`getSolrStatus`](../tools%20and%20functions/client_functions.md#getsolrstatus).

The function uses a grep command for the following message that indicates Solr is active:

```Bash
grep  "^.*\[I2AVAILABILITY] .*  SolrHealthStatusLogger         - '.*', .*'ALL_REPLICAS_ACTIVE'"
```
