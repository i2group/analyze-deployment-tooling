# Database roles, users, and logins

During the deployment, administration, and use of i2 Analyze, a number of different actions are completed against the Information Store database. These actions can be separated into different categories that are usually completed by users with differing permissions. In SQL Server, you can create a number of database roles and assign users to roles.  In the example deployment, a number of different roles and users are used to demonstrate the types of roles that might complete each action.

## <a name="databaseroles"></a> Database roles

In the example, the following roles are used:

| Role              | Description                                                                                                           |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| DBA_Role          | The `DBA_Role` is used to perform database administrative tasks.                                 |
| External_ETL_Role | The `External_ETL_Role` is used to move data from an external system into the staging tables in the Information Store database. |
| i2_ETL_Role       | The `i2_ETL_Role` is used to read data from the staging tables and ingest it into - and delete it from - the Information Store database.                         |
| i2analyze_Role    | The `i2analyze_Role` is used to complete actions required by the Liberty application. For example, returning results for Visual Queries.                                         |


## <a name="databaserolepermissions"></a> Database role permissions

Each database role requires a specific set of permissions to complete the actions attributed to them.

### <a name="dbarole"></a> DBA_Role

The `DBA_Role` requires permissions to:
- Set up and maintain the database management system and Information Store database.
- Create and modify the database management system objects. For example, bufferpools, tablespaces, and filegroups.
- Create and modify database objects. For example, tables, views, indexes, sequences.
- Troubleshoot performance or other issues. For example, has all privileges on all tables. This can be restricted in some environments.
- Configure high availability.
- Manage backup and recovery activities.

Additionally, the role requires access to two roles in the `msdb` database:
- `SQLAgentUserRole` - for more information, see [SQLAgentUserRole Permissions](https://docs.microsoft.com/en-us/sql/ssms/agent/sql-server-agent-fixed-database-roles?view=sql-server-ver15#sqlagentuserrole-permissions)
- `db_datareader` - for more information, see [Fixed-Database Roles](https://docs.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles?view=sql-server-ver15#fixed-database-roles)

These roles are required for database creation, to initialize the deletion-by-rule objects, and to create the SQL Server Agent jobs for the deletion rules.
Note: The `configureDbaRolesAndPermissions.sh` script is exectued during deploy to grant the correct permissions.

The following table provides an overview of the permissions required on the schemas in the Information Store database:

| Schema     | Permissions                                       | Notes                                                        |
| ---------- | ------------------------------------------------- | ------------------------------------------------------------ |
| All        | CREATE TABLE, CREATE VIEW, CREATE SYNONYM         | Required to create the database objects.                      |
| All        | ALTER, SELECT, UPDATE, INSERT, DELETE, REFERENCES | Required to make changes for maintaining the database.        |
| IS_Core    | EXECUTE                                           | Required for deletion-by-rule and database configuration.     |
| IS_Public  | EXECUTE                                           | Required to run the stored procedures for deletion-by-rule.   |

The following table provides an overview of the permissions required on the schemas in the `msdb` database:

| Schema     | Permissions                           | Notes                                                                                    |
| ---------- | ------------------------------------- | ---------------------------------------------------------------------------------------- |
| dbo        | SQLAgentUserRole                      | Required to create the deletion jobs during deployment, and to manage the deletion job schedule.   |
| dbo        | db_datareader                         | Required to create the deletion job schedule.                                             |

The following table provides an overview of the permissions required on the schemas in the `master` database:

| Schema     | Permissions                           | Notes                                                                 |
| ---------- | ------------------------------------- | ----------------------------------------------------------------------|
| All        | VIEW SERVER STATE                     | Required for deletion-by-rule automated jobs via the SQL Server Agent. |
| sys        | EXECUTE ON fn_hadr_is_primary_replica | Required for deletion-by-rule automated jobs.                          |

The `configureDbaRolesAndPermissions.sh` script is used to configure the DBA user with all the required role memberships and permissions.

### <a name="externaletlrole"></a> External_ETL_Role

The `External_ETL_Role` requires permissions to move data from external systems into the Information Store staging tables.

For example, it can be used by an ETL tool - such as DataStage or Informatica - to move and transform data that results in populated staging tables in the Information Store staging schema.

The following table provides an overview of the permissions required on the schemas in the Information Store database:

| Schema     | Permissions                      | Notes                                                             |
|------------|----------------------------------|-------------------------------------------------------------------|
| IS_Staging | SELECT, UPDATE, INSERT, DELETE   | Required to populate the staging tables with date to be ingested or deleted. |

In addition to these permissions, in an environment running SQL server in a Linux container, users with this role must also be a member of the `sysadmin` group in order to perform BULK INSERT into the external staging tables.

The `addEtlUserToSysAdminRole.sh` script is used to make the `etl` user a member of the `sysadmin` fixed-server role. 

### <a name="i2etlrole"></a> i2_ETL_Role

The `i2_ETL_Role` requires permissions to use the i2 Analyze ingestion tools to ingest data from the staging tables into the Information Store.

The following table provides an overview of the permissions required on the schemas in the Information Store database:

| Schema     | Permissions                           | Notes                                                                                                |
| ---------- | ------------------------------------- | -----------------------------------------------------------------------------------------------------|
| IS_Staging | ALTER, SELECT, UPDATE, INSERT, DELETE | Required by the ingestion tools to create and modify objects during the ingestion process.           |
| IS_Stg     | ALTER, SELECT, UPDATE, INSERT, DELETE | Required by the ingestion tools to create and modify objects during the ingestion process.           |
| IS_Meta    | SELECT, UPDATE, INSERT                | UPDATE and INSERT are required to update the ingestion history table. SELECT is required to read the schema meta data. |
| IS_Data    | ALTER, SELECT, UPDATE, INSERT, DELETE | ALTER is required to drop and create indexes and update statistics as part of the ingestion process. |
| IS_Public  | ALTER, SELECT                         | ALTER is required to delete and create synonyms when enabling merged property views. |
| IS_Core    | SELECT, EXECUTE                       | Required to check configuration of the database. | 

### <a name="i2analyzerole"></a> i2analyze_Role

The `i2analyze_Role` requires permissions to complete actions required by the Liberty application. These actions include:
- Visual Query, Find Path, Expand, Add to chart, Upload, and Online upgrade.


The following table provides an overview of the permissions required on the schemas in the Information Store database:

| Schema     | Permissions                           | Notes |
| ---------- | ------------------------------------- | ----- |
| IS_Staging | ALTER, SELECT, UPDATE, INSERT, DELETE | Required to run deletion-by-rule jobs. |
| IS_Stg     | ALTER, SELECT, UPDATE, INSERT, DELETE | Required to upload and delete records via Analyst's Notebook Premium and to run deletion-by-rule jobs. |
| IS_Meta    | SELECT, UPDATE, INSERT, DELETE        | DELETE is required to process the ingestion history queue. |
| IS_Data    | SELECT, UPDATE, INSERT, DELETE        | UPDATE, INSERT, and DELETE are required by deletion-by-rule and to upload and delete records via Analyst's Notebook Premium. |
| IS_Core    | SELECT, UPDATE, INSERT, DELETE        | Required for online upgrade. |
| IS_VQ      | SELECT, UPDATE, INSERT, DELETE        | Required to complete Visual Queries. |
| IS_FP      | SELECT, INSERT, EXEC                  | Required to complete Find Path operations. |
| IS_WC      | SELECT, UPDATE, INSERT, DELETE        | Required to work with Web Charts. |

### The database backup operator role

The example also demonstrates how to perform a database backup, the `dbb` user will perform this action and is a member of the SQL server built in role `db_backupoperator`. This gives this user the correct permissions for performing a backup and nothing else.

For more information, see [Fixed-Database Roles](https://docs.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles?view=sql-server-ver15#fixed-database-roles) for more details.

## <a name="databaseusersandlogins"></a> Database users and logins

In the example, a user is created for each role described previously. These users are then used throughout the deployment and administration steps to provide a reference for when each role is required.


The following users and logins are used in the example:

| User and login | Description | Secrets |
| --- | --- | --- |
| `sa`            | The system administrator user. The `sa` user has full permissions on the database instance. This user creates the Information Store database, roles, users, and logins. | The password is in the `SA_PASSWORD` file, and the username is in the `SA_USERNAME` file in the `secrets/sqlserver` directory. |
| `i2analyze`     | The `i2analyze` user is a member of the `i2analyze_Role`. | The password is in the `DB_PASSWORD` file, and the username is in the `DB_USERNAME` file in the `secrets/liberty` directory.  |
| `etl`           | The `etl` user is a member of `External_ETL_Role`. | The password is in the `DB_PASSWORD` file, and the username is in the `DB_USERNAME` file in the `secrets/etl` directory.      |
| `i2etl`         | The `i2etl` user is a member of `i2_ETL_Role`. | The password is in the `DB_PASSWORD` file, and the username is in the `DB_USERNAME` file in the `secrets/i2etl` directory.    |
| `dba`           | The `dba` user is a member of `DBA_Role`. | The password is in the `DB_PASSWORD` file, and the username is in the `DB_USERNAME` file in the `secrets/dba` directory.      |
| `dbb`           | The `dbb` user is the database backup user, it is a member of the SQL Server built in role: `db_backupoperator`. | The password is in the `DB_PASSWORD` file, and the username is in the `DB_USERNAME` file in the `secrets/dbb` directory.      |

The `sa` user and login exists on the base SQL Server image. The `sa` user is used to create the following artefacts:  
- Database: `ISTORE` 
- Roles: `i2analyze_Role`, `External_ETL_Role,`, `i2_ETL_Role` and `DBA_Role`
- Logins: `i2analyze`, `etl`, `i2etl`, `dba`, and `dbb`
- Users: `i2analyze`, `etl`, `i2etl`, `dba`, and `dbb`

The roles and users must be created after the Information Store database is created.

## <a name="creatingtheroles"></a> Creating the roles

The `sa` user is used to run the `createDbRoles.sh` client function that creates the `i2Analyze_Role`, `External_ETL_Role", i2_ETL_Role`, and `DBA_Role` roles. 

To create the roles, the `createDbRoles.sh` script is run using the `runSQLServerCommandAsSA` client function. This function uses an ephemeral SQL Server client container to create the database roles. For more information about the client function, see:
- [runSQLServerCommandAsSA](../tools%20and%20functions/client_functions.md#runsqlservercommandassa)
- [createDbRoles.sh](../../images/sql_client/db-scripts/createDbRoles.sh)

All the secrets required at runtime by the client container are made available by providing a file path to the secret which is converted to an environment variable by the docker container.

For example to provide the `SA_USERNAME` environment variable to the client container, a file containing the secret in declared in the docker run command: 
`-e "SA_USERNAME_FILE=${CONTAINER_SECRETS_DIR}/SA_USERNAME_FILE" \` the file name can be anything, but the environment variable is fixed.  For more information see: [Managing container security](./security.md)

In the example, the `createDbRoles.sh` script is called in `deploy.sh`.

## <a name="createtheloginanduser"></a> Create the login and user

Use the `sa` user to create the login and the user on the `ISTORE`, and make the user a member of the role.

You can use an ephemeral SQL Client container to create the login and the user.

The [createDbLoginAndUser.sh](../../images/sql_client/db-scripts/createDbLoginAndUser.sh) script in `/images/sql_client/db-scripts` is used to create the login and user. The scripts is called from the  `deploy.sh` scripts.

### <a name="thecreatedbloginanduserfunction"></a> The `createDbLoginAndUser` function

The `createDbLoginAndUser` function uses an ephemeral SQL Client container to create the database administrator login and user. The login and user are created by the `sa` user.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `createDbLoginAndUser.sh` script is used to create the login and user.

The function requires the following environment variables to run:

| Environment variable  | Description |
| ----------------------| ----------- |
| `SA_USERNAME`         | The sa username. |
| `SA_PASSWORD`         | The sa user password. |
| `DB_USERNAME`         | The database user name. |
| `DB_PASSWORD`         | The database user password. |
| `DB_SSL_CONNECTION`   | Whether to use SSL for connection. |
| `SSL_CA_CERTIFICATE`  | The path to the CA certificate. |
| `DB_SERVER`           | The fully qualified domain name of the database server. |
| `DB_PORT`             | Specifies the port number to connect to the Information Store. |
| `DB_NAME`             | The name of the Information Store database. |
| `DB_ROLE`             | The name of the role that user will be added to. It has to be one of the roles from [this list](#databaseroles). |


## <a name="changingsapassword"></a> Changing SA password

In a Docker environment, you must start the SQL Server as the existing `sa` user before you can modify the password.

### <a name="thechangesapasswordfunction"></a> The `changeSAPassword` function

The `changeSAPassword` function uses an ephemeral SQL Client to change the `sa` user password.

For more information about running a SQL Client container and the environment variables required for the container, see [SQL Client](../images%20and%20containers/sql_client.md).

The `changeSAPassword.sh` script is used to change the password.

The function requires the following environment variables to run:

| Environment variable  | Description |
| --------------------- | ----------- |
| `SA_USERNAME`         | The sa username|
| `SA_OLD_PASSWORD`     | The current sa password. |
| `SA_NEW_PASSWORD`     | The new sa password. |
| `DB_SSL_CONNECTION`   | Whether to use SSL for connection. |
| `SSL_CA_CERTIFICATE`  | The path to the CA certificate. |
| `DB_SERVER`           | The fully qualified domain name of the database server. |
| `DB_PORT`             | Specifies the port number to connect to the Information Store. |
