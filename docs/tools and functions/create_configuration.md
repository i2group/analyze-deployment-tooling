#  Creating the configuration

Before you can deploy i2 Analyze, the configuration for the deployment must exist.

You can create the configuration by running the `environments/pre-prod/createConfiguration.sh` script.

The following descriptions explain what the `createConfiguration.sh` script does in more detail.

## Creates the base configuration

The configuration is created in `environments/pre-prod/`. The configuration is created from the `all-patterns` base configuration in the minimal toolkit.

The base configuration can be used for any of the deployment patterns, however some properties are for specific patterns. By default, a schema and security schema are specified. The schemas that are used are based on the `law-enforcement-schema.xml`.

## Copies the JDBC drivers

The JDBC drivers are copied from the `pre-reqs/jdbc-drivers` directory to the `configuration/environment/common/jdbc-drivers` directory in your configuration.

## Configures Form Based Authentication

The `createConfiguration.sh` scripts configures form based authentication in the `environments/pre-prod/configuration/fragments/common/WEB-INF/classes/server.extensions.xml`.

## Copies Solr configuration files

The `createConfiguration.sh` scripts creates the `solr` directory in `environments/pre-prod/configuration/solr`. This directory contains the managed-schema, Solr synonyms file and Solr config files for each index.

The `SOLR_LOCALE` variable located in `common_variables` is used to create the the Solr directory with the files for that locale.

The supported locales are:

- `en_US`
- `ar_EG`
- `he_IL`