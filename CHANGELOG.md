# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [semantic versioning](https://i2group.github.io/analyze-containers/guidetoc/index.html#support-policy):

* `Added` for new features.
* `Changed` for changes in existing functionality.
* `Deprecated` for soon-to-be removed features.
* `Removed` for now removed features.
* `Fixed` for any bug fixes.
* `Security` in case of vulnerabilities.

## 2.6.0 - 24/07/2023

### Added

* Updated for compatibility with i2 Analyze 4.4.2
* Ability to add additional web content to the Liberty server.
* Support for upgrading all previous backups during the upgrade process.

### Changed

* Update SQL Server version to 2022. *Important: This requires JDBC driver version 12.2.0 (minimum)*
* Improved database configuration UX for change sets.

### Fixed

* Incorrect warnings for i2 Connect server version validation are no longer displayed.
* A config that includes `overrideHttpAuthMethod="CLIENT_CERT"` in the `server.extensions.xml` can be deployed successfully.
* Fixed JDBC driver version validation for `create-environment` script

[2.6.0]: <!-- markdown-link-check-disable --><https://github.com/i2group/analyze-containers/tree/v2.6.0><!-- markdown-link-check-enable -->

## 2.5.3 - 07/06/2023

### Added

* Ability to update the Solr configuration without cleaning the deployment first.

### Changed

* Increased the certificate expiry time for the development environment certificates from 90 days to 365 days.

### Fixed

* Security schema changes now included in change sets
* The pre-prod example deployment now backs up the match_index2
* Versions are correctly resolved in documentation

[2.5.3]: <https://github.com/i2group/analyze-containers/tree/v2.5.3>

## 2.5.2 - 31/03/2023

### Added

* Documentation to describe how to create your own repositories to deploy in an air-gapped system.

### Changed

* Improved documentation for creating and using the config development environment.

### Fixed

* Stopped filling Grafana logs with unnecessary messages.
* Database creation scripts no longer contain empty placeholders.
* Can now create ingestion sources in an upgraded system.
* The Liberty user registry is updated during a deploy.
* Stopped repeating Liberty properties on start up.
* Password generation issues on Mac OS

[2.5.2]: <https://github.com/i2group/analyze-containers/tree/v2.5.2>

## 2.5.1 - 14/02/2023

### Changed

* Improved validation on scripts

### Fixed

* Fixed documentation Docker bind examples
* Fixed pre-prod upgrade from v2.3.0

### Workaround

* Upgrading from v2.2.0 after a you complete a back up results in connectors that cannot be recovered. Before you upgrade, run `deploy -c <config_name> -t connectors`.

[2.5.1]: <https://github.com/i2group/analyze-containers/tree/v2.5.1>

## 2.5.0 - 20/12/2022

### Added

* Updated for compatibility with i2 Analyze 4.4.1
* Support for PostgreSQL
* General documentation improvements and bug fixes

### Changed

* The Liberty Docker image now based on the Open Liberty Docker image.
* Node based connectors are built with the dependencies that are defined in a npm-shrinkwrap.json file if the file exist in the connector.
* Improved shared configuration UX by changing `configure-paths` script parameters. Use the `-h` flag for more information on how to run the command.
* `manage-environment -t upgrade` and `manage-toolkit-configuration -t {create | prepare | import | export}` commands now use the path specified in the `path-configuration.json` file instead of the `-p` flag. Use the `-h` flag in each script for more information on how to run the commands.

[2.5.0]: <https://github.com/i2group/analyze-containers/tree/v2.5.0>

## 2.4.0 - 23/09/2022

### Added

* Support for sharing configurations between users and environments
* Support for deploying i2 Notebook plugins
* Support for stopping all running containers

### Changed

* Scripts have been converted to commands
  * For example, `deploy.sh` is now called using `deploy`
* The client functions in `client_functions.sh` are renamed

### Deprecated

* The top-level `.sh` scripts. Start using the commands instead.
* The client functions with the previous names. Start using the renamed functions.


[2.4.0]: <https://github.com/i2group/analyze-containers/tree/v2.4.0>

## 2.3.0 - 22/07/2022

### Added

* Updated for compatibility with i2 Analyze 4.4.0
* Support for Prometheus and Grafana

### Changed

* The environment must be run inside a VS Code development container
* The base Docker images are no longer built locally. The images are pulled from [docker hub - i2group](https://hub.docker.com/u/i2group)

[2.3.0]: <https://github.com/i2group/analyze-containers/tree/v2.3.0>

## 2.2.0 [Deprecated] - 06/05/2022

### Added

* Updated for compatibility with i2 Analyze 4.3.5
* Provided i2 Analyze Fix Pack support
* Script to create database backups for all configs

### Removed

* i2Connect SDK connector base image

## 2.1.3 [Deprecated] - 13/05/2022

### Added

* Functionality to support upgrading to future releases of i2 Analyze

## 2.1.2 [Deprecated] - 31/03/2022

### Security

* Updated the Liberty and Solr images to use Log4j2 version 2.17.2 to remediate <https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-44228>
  * To remediate the CVE, you must rebuild the Docker images in your environment. To rebuild the Docker images, complete the instructions [Updating to the latest version of the analyze-containers repository](https://i2group.github.io/analyze-containers/content/managing_update_env.html).

## 2.1.1 [Deprecated] - 12/01/2022

### Security

* Updated the Liberty and Solr images to use Log4j2 version 2.17.1 to remediate <https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-44228>
  * To remediate the CVE, you must rebuild the Docker images in your environment. To rebuild the Docker images, complete the instructions [Updating to the latest version of the analyze-containers repository](https://i2group.github.io/analyze-containers/content/managing_update_env.html).

## 2.1.0 [Deprecated] - 06/10/2021

### Added

* Support for i2 Connect server connectors developed using the i2 Connect SDK
* Enabled connections to i2 Connect connectors hosted outside of the config development environment
* Synchronize configuration between the config development environment and the i2 Analyze deployment toolkit
* Deploy extensions to the config development environment from i2 Analyze Developer Essentials

### Changed

* Additional command line tools required.
  * See [Updating to the latest version of the analyze-containers repository](https://i2group.github.io/analyze-containers/content/managing_update_env.html).

## 2.0.0 [Deprecated] - 23/07/2021

### Added

* Configuration development environment
* Documentation hosted at <https://i2group.github.io/analyze-containers/>
* Updated for compatibility with i2 Analyze 4.3.4

### Changed

* Moved `environments/pre-prod` to `examples/pre-prod`

## 1.1.0 [Deprecated] - 18/02/2021

### Added

* Walkthroughs to demonstrate backup and restore procedure
* Updated for compatibility with i2 Analyze 4.3.3.1

## 1.0.1 [Deprecated] - 29/01/2021

### Added

* Walkthroughs to demonstrate high availability and disaster recovery scenarios
* New client functions added - getSolrStatus & runi2AnalyzeToolAsExternalUser
* Documentation for the environments/pre-prod/resetRepository.sh script

### Fixed

* environments/pre-prod/walkthroughs/change-management/ingestDataWalkthrough.sh fixed to ingest all of the data in the example data set
* Broken links in markdown documentation

## 1.0.0 [Deprecated] - 17/12/2020

### Added

* Initial public release
* Docker image creation scripts
* Scripts to deploy all EIA components in Docker containers
* Scripts to demonstrate secrets management and full end to end encryption
* Scripts to demonstrate configuration change management across the deployment

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html

<!-- markdownlint-configure-file { "MD024": false } -->
