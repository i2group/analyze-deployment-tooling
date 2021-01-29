# Loss of the ZooKeeper quorum
This walkthrough demonstrates losing more than 50% of the ZooKeeper servers from an ensemble, which causes the loss of the quorum. It also describes how to identify failure, and reinstate high availability with your ZooKeeper ensemble.

Before you begin the walkthrough, there are a number of concepts that it is useful to understand:
* How ZooKeeper is deployed for high availability and how the ensemble functions when one or more ZooKeeper
servers fail. For more information, see [Configuring ZooKeeper for HADR](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.3/com.ibm.i2.deploy.example.doc/hadr_zk.html).
*  When the ZooKeeper quorum is lost, the Solr cluster also fails. To monitor that whether the ZooKeeper quorum is met or not the component availability log in Liberty is used. The status of Solr is used to determine the status of ZooKeeper.
* In a containerised deployment, all log messages are also displayed in the console. You can use the `docker logs` command to view the console log.

## Simulating loss of quorum
To simulate a loss of quorum, more than 50% of the ZooKeeper servers must be stopped. For example, to stop `zk1` and `zk2`, run:
```sh
docker stop zk1 zk2
```

See the `Simulating Zookeeper Quorum failure` section of the walkthrough script. 

## Detecting failure
When the ZooKeeper quorum is lost, the Solr cluster also fails. The Solr status is reported as `DOWN`. For more information about losing Solr, see [Failure of the Solr cluster](./solr_cluster_failure.md).

The `detecting failure` section of the walkthrough script runs a loop around the `getSolrStatus` client function that reports the status of Solr. For more information about the function, see [`getSolrStatus`](../tools%20and%20functions/client_functions.md#getsolrstatus).

The function uses a grep command for the following message that indicates Solr is down:

```Bash
grep -q "^.*[com.i2group.apollo.common.toolkit.internal.ConsoleLogger] - (opal-services) - '.*', .*'DOWN'"
```
For more information see the `Detecting failure` section of the walkthrough script.

## Reinstating high availability
To reinstate high availability to the deployment, restart the failed ZooKeeper servers. In this example, restart the ZooKeeper containers by running the following command:
```sh
docker start zk1 zk2
```

When enough ZooKeeper servers are up to achieve at least a `DEGRADED` quorum, the status of the i2 Analyze services is `ACTIVE` and Liberty reports the changes to the Solr cluster status. To ensure the collections recover, monitor the Liberty logs for healthy collections.

See the `Reinstating high availability` section of the walkthrough script.
