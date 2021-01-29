# Failure of a ZooKeeper server
This walkthrough demonstrates losing a single ZooKeeper server from an ensemble, and describes how to identify failure, continue operations, and reinstate high availability with your ZooKeeper ensemble.

Before you begin the walkthrough, there are a number of concepts that it is useful to understand:
* How ZooKeeper is deployed for high availability. For more information, see [Multi-server setup](https://zookeeper.apache.org/doc/r3.6.2/zookeeperAdmin.html#sc_zkMulitServerSetup).
* The ZooKeeper AdminServer is used to monitor the status of the ZooKeeper ensemble [The AdminServer](https://zookeeper.apache.org/doc/r3.6.2/zookeeperAdmin.html#sc_adminserver).

In the `zookeeperServerFailureWalkthrough.sh` script demonstrates stopping one of the ZooKeeper containers, monitoring the status, and reinstating high availability.

## Simulating a server failure
To simulate a server failure in the ensemble, one of the ZooKeeper servers is stopped. For example, to stop `zk1`, run:
```sh
docker stop zk1
```
See the `Simulating ZooKeeper server failure` section of the walkthrough script. 

## Detecting failure 
When one ZooKeeper server goes offline, the other servers can still make a quorum and remain active. Because the ensemble can sustain only one more server failure, the state is defined as `DEGRADED`.

In the walkthrough, the `getZkQuorumEnsembleStatus` function is used to monitor and determine the ensemble status by calling the `commands/srvr` resource on each ZooKeeper servers's
admin endpoint and reports the status as `DEGRADED` when one of the servers is unavailable.

See the `Detecting failure` section of the walkthrough script.

## Restoring high availability
To restore high availability to the ensemble, restart the failed ZooKeeper server. In this example, restart the ZooKeeper container by running the following command:
```sh
docker start zk1
```

When the ZooKeeper server is up again, the status of the ensemble is `ACTIVE`.

In the walkthrough, the `getZkQuorumEnsembleStatus` function is used again to determine the ensemble status.

See the `Reinstating high availability` section of the walkthrough script.