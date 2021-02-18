# Backup

This section describes the process to back up the Solr collections and the Information Store database in SQL Server in an i2 Analyze deployment in a containerised environment.

## Understanding the back up process

In a deployment of i2 Analyze, data is stored in the Information Store database and indexed in Solr collections. You must back up these components as a pair to enable you to restore the data in your system after a failure. When you back up the Solr collections, the configuration in ZooKeeper is also backed up.

To ensure that data can be restored correctly, you must back up the components in the following order:
1. Solr collections
1. Information Store database

If data is changed in the database after taking the Solr backup, Solr can update the index to reflect these changes when the collections and database are restored.

When you create your backups, ensure that you store both backups so that you can identify the pair of backups that you must restore if required.
> Note: In the walkthrough, both the database and Solr backups are versioned using the variable `backup_version`. In the walkthrough the backup version is `1`. This is used to create a directory where the all of the backup files are stored for this pair. To create another backup pair, increment the `backup_version` so that the backup files are stored in a different directory.

## Backing up the Solr collections

To back up Solr collections, you must have a shared filesystem available that is shared and accessible by all Solr nodes. In a containerised environment, a backup volume is shared between all Solr containers.

>Note: In the example, the backup volume is mounted to `/backup` in the Solr container.

To ensure solr can write the backup file, you must make sure the solr process has permission to the backup folder. In order for solr to write to the folder the user `solr` and group `0` must have read and write permission to the backup folder. The following chown command is an example that gives the solr process permission to write to the backup location:

```bash
chown -R solr:0 /backup
```

The `runSolrClientCommand` client function is used to run the `BACKUP` API request. The backup operation must be performed for each non-transient collection. The non-transient collections are the `main_index`, `match_index`, and `chart_index`. The following curl command is an example that creates a backup of the `main_index` collection:

```sh
runSolrClientCommand bash -c "curl -u \"\${SOLR_ADMIN_DIGEST_USERNAME}:\${SOLR_ADMIN_DIGEST_PASSWORD}\" --cacert /tmp/i2acerts/CA.cer https://solr1:8983//solr/admin/collections?action=BACKUP&async=main_index_backup&name=main_index_backup&collection=main_index&location=/backup/1/
"
```

To perform a backup operation, use the Solr Collections API. For more information about the backup API command, see [BACKUP: Backup Collection](https://lucene.apache.org/solr/guide/8_7/collection-management.html#backup)

>Note: The BACKUP API request must be an asynchronous call otherwise the backup procedure will timeout. This is done by adding `async` flag with a corresponding id to the curl command. In the above example, this is `&async=main_index_backup`.

See the `Backing up Solr` section of the walkthrough script.

## Determining status of Solr backup

The `Monitoring Solr backup process` section of the walkthrough script runs a loop around the `getAsycRequestStatus` client function that reports the status of the Asynchronous backup request. For more information about the client function, see [`getAsycRequestStatus`](../tools%20and%20functions/client_functions.md#getssycrequeststatus).

See the `Monitoring Solr backup progress` section of the walkthrough script.

## Backing up the system match rules file
The system match rules are stored in the ZooKeeper configuration, and can be backed up by using the Solr ZooKeeper Command Line Interface (zkcli) from the Solr client container.

The `runSolrClientCommand` client function is used to run the `zkcli` command. The following command is an example of how to use the `getfile` command to retrieve the system match rules:

```bash
runSolrClientCommand "/opt/solr-8.7.0/server/scripts/cloud-scripts/zkcli.sh" -zkhost "${ZK_HOST}" -cmd getfile /configs/match_index1/match_index1/app/match-rules.xml /backup/1/system-match-rules.xml
```

> Note: The system match rules file is backed up to the `/backup/1/` folder where the Solr backup is located.

For more information about the ZooKeeper command line utilities, see [Using Solr’s ZooKeeper CLI](https://lucene.apache.org/solr/guide/8_7/command-line-utilities.html#using-solrs-zookeeper-cli).

## Backing up the Information Store database

In the containerised environment, the mounted backup volume is used to store the backup file. Only the Information Store database is backed up. The SQL Server instance and system databases are not included in the backup.

For more information about the backup volume, see [Running a SQL Server](../images%20and%20containers/sql_server.md#runningasqlservercontainer).

The backup is performed by a user that has the built-in `db_backupoperator` SQL Server role. In this case, that is the `dbb` user. Use the `runSQLServerCommandAsDBB` client function to run the following SQL command to create the backup file. For example: 

```sh
runSQLServerCommandAsDBB bash -c "/opt/mssql-tools/bin/sqlcmd -N -b -C -S sqlserver.eia,1433 -U \"\${DB_USERNAME}\" -P \"\${DB_PASSWORD}\" \
    -Q \"USE ISTORE; 
        BACKUP DATABASE ISTORE
        TO DISK = '/backup/1/IStore.bak'
            WITH FORMAT;\""
```

For more information about backing up a SQL Server database, see:
* [Backup SQL Documentation](https://docs.microsoft.com/en-us/sql/t-sql/statements/backup-transact-sql?view=sql-server-ver15)
* [SQL Server Backup Permissions](https://docs.microsoft.com/en-us/sql/t-sql/statements/backup-transact-sql?view=sql-server-ver15#permissions)

For more information about the `dbb` user and it's role, see:
* [db users](../security%20and%20users/db_users.md#databaseusersandlogins)

See the `Backing up SQL Server` section of the walkthrough script.