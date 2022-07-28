# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog], and this project adheres to
[Semantic Versioning]:

* `Added` for new features.
* `Changed` for changes in existing functionality.
* `Deprecated` for soon-to-be removed features.
* `Removed` for now removed features.
* `Fixed` for any bug fixes.
* `Security` in case of vulnerabilities.

## 2.3.0 - 22/07/2022

### Added

* Updated for compatibility with i2 Analyze 4.4.0
* Support for Prometheus and Grafana

### Changed

* The environment must be run inside a VS Code development container
* The base Docker images are no longer built locally. The images are pulled from [docker hub - i2group](https://hub.docker.com/u/i2group)

[2.3.0]: <!-- markdown-link-check-disable --><https://github.com/i2group/analyze-containers/tree/v2.3.0><!-- markdown-link-check-enable -->

## 2.2.0 - 06/05/2022

### Added

* Updated for compatibility with i2 Analyze 4.3.5
* Provided i2 Analyze Fix Pack support
* Script to create database backups for all configs

### Removed

* i2Connect SDK connector base image

[2.2.0]: <https://github.com/i2group/analyze-containers/tree/v2.2.0>

## 2.1.3 - 13/05/2022

### Added

* Functionality to support upgrading to future releases of i2 Analyze

[2.1.3]: <https://github.com/i2group/analyze-containers/tree/v2.1.3>

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