# ETL Tools
This topic describes how to perform ETL tasks by using the ETL toolkit in a containerized deployment of i2 Analyze.

All of the tools described here are located in the `images/etl_client` directory. The `etl_client` directory is populated when running [createEnvironment.sh](../../environments/pre-prod/createEnvironment.sh).

The `runEtlToolkitToolAsi2ETL` client function is used to run the ETL tools described in this topic as the i2ETL user. For more information about this client function, see [runEtlToolkitToolAsi2ETL](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl)

## <a name="buildinganetlclientimage"></a> Building an ETL Client image

The ETL client image is built from the Dockerfile in `images/etl_client`. 

The following `docker run` command builds the configured image:

```bash
docker build -t "etl_client" "images/etl_client"
```

## <a name="addinformationstoreingestionsource"></a> Add Information Store ingestion source

The `addInformationStoreIngestionSource` tool defines an ingestion source in the Information Store. For more information about ingestion sources in the Information Store, see [Defining an ingestion source](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.ingestion.doc/define_ingestion_source.html).

You must provide the following arguments to the tool:

| Argument | Description                                                                   | Maximum characters |
| -------- | ----------------------------------------------------------------------------- | ------------------ |
| `n`      | A unique name for the ingestion source                                        | 30                 |
| `d`      | A description of the ingestion source that might appear in the user interface | 100                |

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/addInformationStoreIngestionSource 
        -n <> 
        -d <> "
```

## <a name="createinformationstorestagingtable"></a> Create Information Store staging table

The `createInformationStoreStagingTable` tool creates the staging tables that you can use to ingest data into the Information Store. For more information about creating the tables, see [Creating the staging tables](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.ingestion.doc/create_staging_stables.html).

You must provide the following arguments to the tool:

| Argument | Description                                                                    |
| -------- | ------------------------------------------------------------------------------ |
| `stid`   | The schema type identifier of the item type to create the staging table for    |
| `sn`     | The name of the database schema to create the staging table in                 |
| `tn`     | The name of the staging table to create                                        |

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/createInformationStoreStagingTable 
        -stid <> 
        -sn <>
        -tn <> "
```

## <a name="ingestinformationstorerecords"></a> Ingest Information Store records
The `ingestInformationStoreRecords` is used to ingest data into the Information Store. For more information about ingesting data into the Information Store, see [The ingestInformationStoreRecords toolkit task](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.ingestion.doc/ingestion_command.html)

You can use the following arguments with the tool:

| Argument  | Description |
| --------- | ----------- |
| `imf`     | The full path to the ingestion mapping file. |
| `imid`    | The ingestion mapping identifier in the ingestion mapping file of the mapping to use |
| `im`      | <strong>Optional:</strong> The import mode to use. Possible values are STANDARD, VALIDATE, BULK, DELETE, BULK_DELETE or DELETE_PREVIEW. The default is STANDARD. |
| `icf`     | <strong>Optional:</strong> The full path to an ingestion settings file   |
| `il`      | <strong>Optional:</strong> A label for the ingestion that you can use to refer to it later |  
| `lcl`     | <strong>Optional:</strong> Whether (true/false) to log the links that were deleted/affected as a result of deleting entities | 

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/ingestInformationStoreRecords 
    -imf <> 
    -imid <> 
    -im <>"
```

## <a name="syncinformationstorerecords"></a> Sync Information Store records

The `syncInformationStoreCorrelation` tool is used after an error during correlation, to synchronize the data in the Information Store with the data in the Solr index so that the data returns to a usable state

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/syncInformationStoreCorrelation"
```

## <a name="duplicateprovenancecheck"></a> Duplicate provenance check

The `duplicateProvenanceCheck` tool can be used to for identifying records in the Information Store with duplicate origin identifiers. Any provenance that has a duplicated origin identifier is added to a staging table in the Information Store.

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitTool
    bash -c "/opt/ibm/etltoolkit/syncInformationStoreCorrelation"
```

## <a name="duplicateprovenancedelete"></a> Duplicate provenance delete

The `duplicateProvenanceDelete` tool deletes (entity/link) provenance from the Information Store that has duplicated origin identifiers. The provenance to delete is identified in the staging tables created by the `duplicateProvenanceCheck` tool.

You can provide the following argument to the tool:

| Argument | Description |
| -------- | ----------- |
| `stn`    | The name of the staging table that contains the origin identifiers to delete. |

If no arguments are provided, duplicate origin identifiers are deleted from all staging tables.

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/syncInformationStoreCorrelation"
```

## <a name="generateinformationstoreindexcreationscripts"></a> Generate Information Store index creation scripts

The `generateInformationStoreIndexCreationScript` tool generates the scripts that create the indexes for each item type in the Information Store. For more information about Database index management, see [Database index management](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.ingestion.doc/bulk_index_management.html)

You must provide the following arguments to the tool:

| Argument | Description |
| -------- | ----------- |
| `stid`   | The schema type identifier of the item type to create the index creation scripts for. |
| `op`     | The location to create the scripts. |


Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitTask 
    bash -c "/opt/ibm/etltoolkit/generateInformationStoreIndexCreationScript 
    -op <>
    -stid <> "
```

For more information about Database index management, see [Database index management](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/bulk_index_management.html?cp=SSXVXZ_2.3.2)

## <a name="generateinformationstoreindexdropscripts"></a> Generate Information Store index drop scripts

The `generateInformationStoreIndexDropScript` tool generates the scripts that drop the indexes for each item type in the Information Store. For more information about Database index management, see [Database index management](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.ingestion.doc/bulk_index_management.html)

You must provide the following arguments to the tool:

| Argument | Description |
| -------- | ----------- |
| `stid`   | The schema type identifier of the item type to create the index drop scripts for. |
| `op`     | The location to create the scripts. |


Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitTask 
    bash -c "/opt/ibm/etltoolkit/generateInformationStoreIndexDropScript 
    --op <> 
    -stid <> "
```

## <a name="deleteorphaneddatabaseobjects"></a> Delete orphaned database objects

The `deleteOrphanedDatabaseObjects` tool deletes (entity/link) database objects that are not associated with an i2 Analyze record from the Information Store.

You can provide the following arguments to the tool:

| Argument | Description |
| -------- | ----------- |
| `iti`    | <strong>Optional:</strong> The schema type identifier of the item type to delete orphaned database objects for. |

If no item type id is provided, orphaned objects for all item types are removed

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/deleteOrphanedDatabaseObjects 
        -iti <> "
```

## <a name="disablemergedpropertyvalues"></a> Disable merged property values

The `disableMergedPropertyValues` tool removes the database views used to define the property values of merged i2 Analyze records.

You can provide the following arguments to the tool:

| Argument | Description |
| -------- | ----------- |
| `etd`    | The location of the root of the etl toolkit. |
| `stid`   | The schema type identifier to disable the views for. |

If no schema type identifier is provided, the views for all of the item types are be removed

Use the [`runEtlToolkitToolAsi2ETL`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl) client function to run the tool. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/disableMergedPropertyValues 
        -etd <>
        -stid <>"
```

For more information about correlation, see [Information Store data correlation](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.correlation.doc/c_correlation_intro.html?cp=SSXVXZ_2.3.2)

## <a name="enablemergepropertyvalues"></a> Enable merge property values

The `enableMergedPropertyValues` tool creates the database views used to define the property values of merged i2 Analyze records.

You can provide the following arguments to the tool:

| Argument | Description |
| -------- | ----------- |
| `etd`    | The location of the root of the etl toolkit. |
| `stid`   | The schema type identifier to create the views for. |

If no schema type identifier is provided, the views for all of the item types are generated. If the views already exist, they are overwritten.

Use the [`runEtlToolkitToolAsDBA`](../tools%20and%20functions/client_functions.md#runetltoolkittoolasdba) client function to run the tool as the database administrator. For example:

```bash
runEtlToolkitToolAsi2ETL 
    bash -c "/opt/ibm/etltoolkit/enableMergedPropertyValues 
        -etd <> 
        -stid <> "
```

For more information about correlation, see [Information Store data correlation](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.correlation.doc/c_correlation_intro.html?cp=SSXVXZ_2.3.2)