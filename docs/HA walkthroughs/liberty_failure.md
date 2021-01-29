# Failure of the leader Liberty container
This section demonstrates how a deployment of i2 Analyze responds to the failure and recovery of the Liberty server that hosts the leader Liberty instance. This section also describes the messages that you should monitor to detect the failure and ensure that the recovery was successful.

Before you begin the walkthrough, there are a number of concepts that it is useful to understand:
* How Liberty is deployed for high availability and the role of the Liberty leader. For more information about Liberty configuration, see [Liberty](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.eia.go.live.doc/liberty_co.html).
* How a load balancer is used and configured in a deployment of i2 Analyze. For more information about the load balancer configuration, see [Deploying a load balancer](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.deploy.example.doc/hadr_loadbalancer.html).
* That the load balancer is used to monitor the status of the i2 Analyze service.
* In a containerised deployment, all log messages are also displayed in the console. You can use the `docker logs` command to view the console log.

The `libertyHadrFailureWalkthrough.sh` script simulates the Liberty leader failure.

## Identifying the leader Liberty
To simulate a failure of the leader Liberty, first identify which server hosts the leader instance.

To identify which container is running the leader Liberty, check the logs of the Liberty servers for the message: `We are the Liberty leader`.

In the walkthrough script, this is done with the following `grep` command:
```sh
grep -q "We are the Liberty leader"
```

See the `Identifying the leader Liberty` section of the walkthrough script.

## Simulating leader Liberty failure
To simulate leader Liberty failure, stop the leader Liberty. For example, if `liberty1` is the leader, run:
```sh
docker stop liberty1
```
See the `Simulating leader Liberty failure` section of the walkthrough script.

## Detecting failure
The load balancer is used to monitor and determine the status of the i2 Analyze service. The load balancer is configured to report the status of the deployment. The status can be either `ACTIVE`, `DEGRADED`, or `DOWN`.

When the leader is taken offline, the other Liberty server must restart to become the new leader. During this time, both servers are down and the i2 Analyze service is `DOWN`. When the new leader Liberty starts and only 1 of the servers is down, the status of the i2 Analyze services is `DEGRADED`.

In the walkthrough, the `waitFori2AnalyzeServiceStatus` function is used to run a while loop around the `geti2AnalyzeServiceStatus` function to wait until the i2 Analyze service is in the `DEGRADED` state. The `geti2AnalyzeServiceStatus` function is an example of how to return the i2 Analyze service status from a load balancer. 

See the `Detecting failure` section of the walkthrough script.

## Fail over
When the Liberty leader fails, one of the remaining Liberty servers is elected as the leader. To identify the new Liberty leader, check the logs of the remaining Liberty servers for the message: `We are the Liberty leader`.

See the `Fail over` section of the walkthrough script.

## Reinstating high availability
To reinstate high availability to the deployment, restart the failed Liberty server. In this example, that restart the Liberty container by running the following command:
```sh
docker start liberty1
```

When both Liberty servers are up, the status of the i2 Analyze services is `ACTIVE`.

In the walkthrough, the `waitFori2AnalyzeServiceStatus` function is used to run a while loop around the `geti2AnalyzeServiceStatus` function to wait until the i2 Analyze service is in the `ACTIVE` state. The `geti2AnalyzeServiceStatus` function is an example of how to return the i2 Analyze service status from a load balancer. 

The recovered Liberty server is in the non-leader mode when it starts because the new leader has already been elected while the server was unavailable. To determine it is in the non-leader mode, the following message is displayed in the logs: `We are not the Liberty leader`.

See the `Reinstating high availability` section of the walkthrough script.