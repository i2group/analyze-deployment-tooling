# Restore

This section describes the process to restore the Solr collections and Information Store database in SQL Server of an i2 Analyze deployment in a containerised environment.


## Understanding the restore process

To restore the data and indexes for a deployment of i2 Analyze, restore the pair of Solr collection and Information Store database backups.

To ensure that the data is restored correctly, restore the pair of backups in the following order:

1. Information Store database
1. Solr collections

If any data has changed in the Information Store after the Solr backup, the Solr index is updated to reflect the contents of the Information Store database when Liberty is started.

## Preparing the environment

Before you can restore the backups, clean down the Solr, ZooKeeper & SQL Server environment if you are not using a clean environment.

See the `Simulating Clean down` section of the walkthrough script.
  
## Stop the liberty servers

Before the restore process can begin you must stop the liberty servers. In a this can be done by stopping the containers

The following command is an example of how to stop the liberty containers:

```bash
docker container stop liberty1 liberty2
```

## Restoring the Information Store database

The process of restoring the Information Store database contains the following steps:

1. Running a SQL Server container with a new instance of SQL Server 
1. Creating the Information Store database from the backup file in the new instance
1. Recreating the required logins in the new SQL Server instance, and the users in the restored database 

### Running a SQL Server container
Run a container for the new instance of SQL Server, this will have the backup directory available. For more information about running a SQL Server container, see [SQL Server](../images%20and%20containers/sql_server.md).

See the `Running the SQL Server` section of the walkthrough script.

### Creating the database from the backup file
In a new instance of SQL Server, the only user is the `sa` user. Use the `runSQLServerCommandAsSA` client function to run the following SQL command as the `sa` user to create the `ISTORE` database from the backup file:

```sh
runSQLServerCommandAsSA bash -c "/opt/mssql-tools/bin/sqlcmd -N -b -C -S sqlserver.eia,1433 -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" \
    -Q \"RESTORE DATABASE ISTORE FROM DISK = '/backup/IStore.bak;'"
```

See the `Restoring the ISTORE database` section of the walkthrough script.

### Recreating the logins and users

In SQL Server, a login is scoped to the Database Engine. To connect to a specific database, in this case the `ISTORE` database, a login must be mapped to a database user.
Because the backup is completed for the `ISTORE` database only, the logins from the previous SQL Server instance cannot be restored. Additionally, the database users are restored but there are no logins mapped to them.

For more information about SQL Server logins, see [SQL Server Login documentation](https://docs.microsoft.com/en-us/sql/relational-databases/security/authentication-access/create-a-login?view=sql-server-ver15)

In this environment, create the required logins and users by dropping the users from the database and recreating the logins and the users by using the `createDbLoginAndUser` client function. The logins and users are created in the same way as when original SQL Server instance was configured.

For more information about creating the required logins, users, and permissions, see [Configuring SQL Server](../tools%20and%20functions/deploy.md#configuringsqlserver) in the deployment documentation.

See the `Dropping existing database users` and `Recreating database logins, users, and permissions` sections of the walkthrough script.

## Restoring the Solr collections

Restoring the solr indexes includes the following high-level steps:

* Deploy a new Solr cluster and ZooKeeper ensemble
* Restore the non-transient Solr collections
    * Monitor the restore process until completed
* Recreate transient Solr collections
* Restore system match rules

### Deploy a new Solr cluster and ZooKeeper ensemble

To restore the Solr indexes, deploy a new Solr cluster & ZooKeeper ensemble. For more information about running a clean ZooKeeper & Solr environment, see 
* [Running Solr and ZooKeeper](../tools%20and%20functions/deploy.md#runningsolrandzookeeper).
* [Create Solr cluster](../tools%20and%20functions/deploy.md#createsolrcluster).

See the `Deploying Clean Solr & Zookeeper` section of the walkthrough script.

### Restoring the non-transient Solr collections
The `runSolrClientCommand` client function is used to run the `RESTORE` API request. The restore operation must be performed for each non-transient collection that was backed up. The following curl command is an example that restores the `main_index` collection:

```sh
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert /tmp/i2acerts/CA.cer https://solr1:8983/solr/admin/collections?action=RESTORE&async=main_index_backup&name=main_index_backup&collection=main_index&location=/backup/1"
"
```

To perform a restore operation, use the Solr Collections API. For more information about the Restore API command, see [RESTORE: Restore Collection](https://lucene.apache.org/solr/guide/8_7/collection-management.html#restore).

> Note: The restore API request must be an asynchronous call otherwise the restore procedure will timeout. This is done by adding `async` flag with a corresponding id to the curl command. In the above example, this is `&async=main_index_backup`.

See the `Restoring non-transient Solr collection` section of the walkthrough script.

## Determining completion of Solr restore procedure

The `Monitoring Solr restore process` section of the walkthrough script runs a loop around the `getAsycRequestStatus` client function that reports the status of the Asynchronous request. For more information about the client function, see [`getAsycRequestStatus`](../tools%20and%20functions/client_functions.md#getasycrequeststatus).

See the `Monitoring Solr restore progress` section of the walkthrough script.

### Recreate transient Solr collections

Recreate the transient `daod_index` and `highlightquery_index` Solr collections.

For more information about the creating Solr collections, see [Configuring Solr and ZooKeeper](../tools%20and%20functions/deploy.md#configuringsolrandzookeeper).

See the `Recreating transient Solr collections` section of the walkthrough script.

### Restore system match rules

After the indexes are restored, upload the system match rules file. Use the Solr ZooKeeper Command Line Interface (zkcli) to create the directory in ZooKeeper for the system match rules file and to upload it.

The `runSolrClientCommand` client function is used to run the zkcli request.

The following command creates the directory in ZooKeeper where the system match rules file must be stored:

```bash
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd makepath /configs/match_index1/match_index1/app
```

> Note: The path to where the system match rules file must be located is in the following format `configs/<index name>/<index name>/app`

The following command uploads the system match rules file to the directory in ZooKeeper created earlier:

```bash
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd putfile /configs/match_index1/match_index1/app/match-rules.xml /backup/1/system-match-rules.xml
```

For more information about the ZooKeeper command line utilities, see [Using Solr’s ZooKeeper CLI](https://lucene.apache.org/solr/guide/8_7/command-line-utilities.html#using-solrs-zookeeper-cli).

See the `Restoring system match rules` section of the walkthrough script.

## Start the Liberty containers

After the Solr collections and Information Store database are restored, start the Liberty containers. 

The following command is an example of how to start the Liberty containers:

```bash
docker container start liberty1 liberty2
```

After the Liberty containers have started, the `waitFori2AnalyzeServiceToBeLive` common function ensures that the i2 Analyze service is running. For more information, see [Status utilities](../tools%20and%20functions/client_functions.md#status-utilities#waitFori2AnalyzeServiceToBeLive).

See the `Restart Liberty containers` section of the walkthrough script.