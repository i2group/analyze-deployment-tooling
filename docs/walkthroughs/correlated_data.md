# Defining the property values of merged records

This section describes an example of the process to define how property values of merged records are calculated in a Docker environment. 
The process includes the following high-level steps:
* Enabling merged property values
    * To define the view, enable and then modify it to meet your correlation requirements
* Updating property value definitions
* Ingest data that correlates and review its properties

The `mergedPropertyValuesWalkthrough.sh` script is a worked example that demonstrates how to enables and modify the views in a containerized environment.

> Note: Before you complete this walkthrough, reset your environment to the base configuration. For more information, see [Resetting your environment](./reset_walkthroughs.md).

## <a name="defaultmergepropertybehavior"></a> Default merge property behavior

* To demonstrate the default behavior, use the `ingestDataWalkthrough.sh` script to ingest some data the correlates. For more information about ingesting the data, see [Ingesting data into the Information Store](./ingestion.md).

* During the ingestion walk-through, the default behavior is used to determine the property values of the correlated record. In the default behavior, the property values from the merge contributor with the most recent value for `source_last_updated` are used. 

For more information about the how the property values for merged records are calculated, see [Define how property values of merged records are calculated](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.correlation.doc/c_merged_properties.html)

After you ingest the data, in Analyst's Notebook Premium search for `Julia Yochum` and add the returned entity to the chart. Keep the chart open for the remainder of the walkthrough script.

## <a name="enablingmergedpropertyvalues"></a> Enabling merged property values

To inform i2 Analyze that you intend to define the property values of merged records, run the `enableMergedPropertyValues.sh` tool. You can take control of the property values for records of specific item types, or all item types in the i2 Analyze schema.
Note that this operation must be performed by the database administrator.

See the `Enabling merged property values` section of the walkthrough script.

The `runEtlToolkitToolAsDBA` client function is used to run the `enableMergedPropertyValues.sh` tool.
* [runEtlToolkitToolAsDBA](../tools%20and%20functions/client_functions.md#runetltoolkittoolasdba)
* [enableMergedPropertyValues](../tools%20and%20functions/etl_tools.md#enablemergepropertyvalues)
* [Defining the property values of merged i2 Analyze records](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.correlation.doc/t_define_properties.html)

In the `mergedPropertyValuesWalkthrough.sh`, the views are created for the Person item type. The `enableMergedPropertyValues.sh` tool is used in the `Create the merged property views for the CORRELATED_SCHEMA_TYPE_IDS` section.

## <a name="updatingpropertyvaluedefinitions"></a> Updating property value definitions

The walkthrough provides an example `.sql` script that drops the existing `IS_Public.E_Person_MPVDV` view and replaces it with another. The new view prioritizes property values from merge contributors that come from the ingestion source names `EXAMPLE_1` over values from `EXAMPLE_2` and any other sources.  
The `createAlternativeMergedPropertyValuesView.sql` script is in `environments/pre-prod/walkthroughs/configurationChanges`.

After the views are enabled, the merged property values definition view (`Person_MPVDV`) is modified to change how the property values of correlated records are calculated.
Note, this step is also performed by the database administrator.

See the `Updating property value definitions` section of the walkthrough script.

The `runSQLServerCommandAsDBA` client functions in used to run the `createAlternativeMergedPropertyValuesView.sql` script.
* [runSQLServerCommandAsDBA](../tools%20and%20functions/client_functions.md#runsqlservercommandasdba)
* [The merged property values definition view](https://www.ibm.com/support/knowledgecenter/SSXVTH_latest/com.ibm.i2.iap.admin.correlation.doc/c_view_definition.html)

## <a name="reingestingthedata"></a> Reingesting the data

The property values of merged records do not update when the MPVDV views are modified. To update the values of existing records, you must reingest at least one of the merge contributors to the record.

To do this, use the `ingestDataWalkthrough.sh` script to ingest some data the correlates. For more information about ingesting the data, see [Ingesting data into the Information Store](./ingestion.md).

See the `Reingesting the data` section of the walkthrough script.

After the data is ingested, in the Analyst's Notebook Premium chart that you have open, select the `Julia Yochum` item and click **Get changes**. 

The name of the item changes to `Julie Yocham`, because the property values that make up the name are now from the merge contributor where the ingestion source name is `EXAMPLE_1`.
