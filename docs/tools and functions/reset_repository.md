# Resetting the repository

The local repository can be returned to its initial state by running the `resetRepository.sh` script.

The following artifacts are removed by the `resetRepository.sh`:
* All Docker resources such as images, containers, volumes and networks.
* The simulated-secret-store directory.
* Resources that are copied to various image directories when the environment is created.
* Database scripts that are generated as part of the deployment process.
* The ETL toolkit that is located in `images/etl_client/etltoolkit`
* The example connector that is located in `images/example_connector/app`

After you run the `resetRepository.sh` script, you must follow the getting started process from the [Creating a containerised deployment](../getting_started.md#creatingacontaineriseddeployment) section.
