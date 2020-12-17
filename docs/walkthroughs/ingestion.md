# Ingesting data into the Information Store

The `ingestDataWalkthrough.sh` script is a worked example that demonstrates how to script the process of ingesting data into the Information Store.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](../reset_walkthroughs.md).

The example provides a scripted mechanism to ingest data by using ETL toolkit. The script ingests data with and without correlation identifiers using both `STANDARD` and `BULK` import modes.  
For more information about ingestion, see:
- [Information Store data ingestion](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/data_ingestion.html) 
- [Information Store data correlation](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.correlation.doc/c_correlation_intro.html)

To script the ingestion process, the following information is stored within the script:  

* The mapping of item type identifiers to staging tables
* The mapping of staging tables to CSV files and format files.
* A list of import mapping identifiers from the mapping file.

The script uses the `runSqlServerCommandAsETL` client function to import the data into the staging tables, and `runEtlToolkitToolAsi2ETL` to run the ingestion commands.
Note the external ETL user is performing the import into the staging tables, but the i2 Internal ETL user is executing ETL tasks such as creating the ingestion source or performing the import from the stagin tables.

The data and ingestion artefacts that are used in the example are in the `examples/data` directory of the minimal toolkit. 

## Creating the ingestion sources

The `runEtlToolkitToolAsi2ETL` client function is used to run `addInformationStoreIngestionSource` ETL toolkit tool to create the ingestion sources.
* [runEtlToolkitToolAsi2ETL](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl)
* [addInformationStoreIngestionSource](../tools%20and%20functions/etl_tools.md#add-information-store-ingestion-source)
* For more information about ingestion sources in the Information Store, see [Defining an ingestion source](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/define_ingestion_source.html)

For an example of how to use the tool, see the `Create the ingestion sources` section in the `ingestDataWalkthrough.sh`

## Creating the staging tables

The `runEtlToolkitToolAsi2ETL` client function is used to run `createInformationStoreStagingTable` ETL toolkit tool to create the staging tables.
* [runEtlToolkitToolAsi2ETL](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl)
* [createInformationStoreStagingTable](../tools%20and%20functions/etl_tools.md#create-information-store-staging-table)
* For more information about creating staging tables in the Information Store, see [Creating the staging tables](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/create_staging_stables.html)

To create all of the staging tables in the example, schema type identifiers are mapped to staging table names. For an example of how the mappings are used, see the `Create the staging tables` section in the `ingestDataWalkthrough.sh`

> Note: Because there are multiple staging tables for the `LAC1` link type, a second loop is used to iterate through the staging table names of each schema type.

## Ingesting data

The walkthrough demonstrates how to ingest both non-correlated and correlated data.
For each type of data the staging tables and populated, the data ingestion task is executed, then the staging tables are cleaned.

### Ingesting non correlated data

In this case, the SQL Server `BULK INSERT` command is used to insert the CSV data into the staging tables.

### Ingesting correlated data

See the `Ingesting correlated data` section of the walkthrough script. 

### The ingestion procedure

The `runSqlServerCommandAsETL` client function is used to run the sql statement that inserts the data into the staging tables.
* [runSqlServerCommandAsETL](../tools%20and%20functions/client_functions.md#runsqlservercommandasetl)
* [Populating the staging tables](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/c_stage_data.html)

The example uses CSV and format files to insert the data. The files have the same name (`person.csv` and `person.fmt`). The staging table names are mapped to the CSV and format files. There is one mapping for base data (`BASE_DATA_TABLE_TO_CSV_AND_FORMAT_FILE_NAME`) and one for correlation data (`CORRELATED_DATA_TABLE_AND_FORMAT_FILE_NAME`).
For an example of how the mappings are used, see the `Insert the base data into the staging tables` section in the `ingestDataWalkthrough.sh`

The `runEtlToolkitToolAsi2ETL` client function is used to run `ingestInformationStoreRecords` ETL toolkit tool to ingest the data into the Information Store from the staging tables.
* [runEtlToolkitToolAsi2ETL](../tools%20and%20functions/client_functions.md#runetltoolkittoolasi2etl)
* [ingestInformationStoreRecords](../tools%20and%20functions/etl_tools.md#ingest-information-store-records)
* [The ingestInformationStoreRecords toolkit task](https://www.ibm.com/support/knowledgecenter/SSXVTH_4.3.2/com.ibm.i2.iap.admin.ingestion.doc/ingestion_command.html)

The `ingestInformationStoreRecords` tool is used with `BULK` and `STANDARD` import modes. Standard import mode is used to ingest the correlation data sets.
Bulk import mode is used to ingest the base data set.

The import mapping identifiers to use with the `ingestInformationStoreRecords` tool are defined in the `IMPORT_MAPPING_IDS` and `BULK_IMPORT_MAPPING_IDS` lists.

A loop is used to ingest data for each mapping identifier in the lists. 