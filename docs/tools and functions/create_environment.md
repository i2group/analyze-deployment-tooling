# Creating the environment

Before you can deploy i2 Analyze in a containerised environment, the local environment must be created. The local environment requires the prerequisites to be in the correct locations, and copies some artifacts and tools from the i2 Analyze toolkit.

You can create the local environment by running the `environments/pre-prod/createEnvironment.sh` script.

The following descriptions explain what the `createEnvironment.sh` script does in more detail.

## Extracts the i2 Analyze minimal toolkit

The script extracts the toolkit `tar.gz` located in the `pre-reqs` directory into the the `pre-reqs/i2Analyze` directory.

## Populate image clients

The `createEnvironment.sh` script creates populate client images with the contents of the `i2-tools` & `scripts` folder of the toolkit.

## ETL toolkit

The `createEnvironment.sh` script creates the ETL toolkit that is built into the etl toolkit image. The etl toolkit is created in `images/etl_client/etltoolkit`.

## Example connector application

The `createEnvironment.sh` script creates the example connector that is built into the connector image. The application consists of the contents of `i2analyze/toolkit/examples/connectors/example-connector`. The connector application is created in `images/example_connector/app`.

## Liberty application

The `createEnvironment.sh` script creates the i2 Analyze liberty application that is built into the Liberty base image. The application consists of files that do not change based on the configuration. After the application is created, you do not need to modify it. The application is created in `images/liberty_ubi_base/application`.

The content of the application depends on the deployment pattern that is used. To specify the deployment pattern, set the value of the `DEPLOYMENT_PATTERN` variable located in `createEnvironment.sh`. By default, the `information-store-daod-opal` pattern is used.

The supported deployment patterns are:

- `information-store-daod-opal`
- `daod-opal`
- `chart-storage`
- `chart-storage-daod`
- `information-store-opal`

