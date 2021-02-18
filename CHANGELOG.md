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

## [1.1.0] - 18/02/2021

### Added

* Walkthroughs to demonstrate backup and restore
* New client function added - getAsyncRequestStatus
* New volumes added to Solr and SQL Server containers for backup and restore
* Updated for compatibility with i2 Analyze 4.3.3.1

[1.1.0]: https://github.com/IBM-i2/Analyze-Containers/tree/v1.1.0
## [1.0.1] - 29/01/2021

### Added

* Walkthroughs to demonstrate high availability and disaster recovery scenarios
* New client functions added - getSolrStatus & runi2AnalyzeToolAsExternalUser
* Documentation for the environments/pre-prod/resetRepository.sh script

### Fixed

* environments/pre-prod/walkthroughs/change-management/ingestDataWalkthrough.sh fixed to ingest all of the data in the example data set
* Broken links in markdown documentation

[1.0.1]: https://github.com/IBM-i2/Analyze-Containers/tree/v1.0.1

## [1.0.0] - 17/12/2020

### Added

* Initial public release
* Docker image creation scripts
* Scripts to deploy all EIA components in Docker containers
* Scripts to demonstrate secrets management and full end to end encryption
* Scripts to demonstrate configuration change management across the deployment

[1.0.0]: https://github.com/IBM-i2/Analyze-Containers/tree/v1.0.0

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html