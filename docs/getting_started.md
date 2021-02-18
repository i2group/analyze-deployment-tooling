# Getting started with the Analyze-Containers repository

## <a name="prerequisites"></a> Prerequisites

### <a name="code"></a> Code
Download the `tar.gz` or clone the Analyze-Containers repository from https://github.com/IBM-i2/Analyze-Containers/releases.

### <a name="windowssubsystemforlinux"></a> Windows Subsystem for Linux (WSL)

If you are on Windows, you must use WSL 2 to run the shell scripts in this repository.

For information about installing WSL, see [Windows Subsystem for Linux Installation Guide](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

### <a name="docker"></a> Docker

You must install Docker CE for your operating system. For more information about installing Docker CE, see https://docs.docker.com/engine/installation/.

- *Mac OS* : [Install Docker CE](https://docs.docker.com/docker-for-mac/install/)
- *Windows* : 
    1. [Install Docker CE](https://docs.docker.com/docker-for-windows/install/)
    1. [Set up Docker on WSL 2](https://docs.docker.com/docker-for-windows/wsl/) 

When you configure Docker, give Docker permission to mount files from the `Analyze-Containers` directory on your local file system. In the *Docker Desktop* application, navigate to  `Settings > Resources > File Sharing`.

After you install Docker, you must allocate enough memory to Docker to run the containers in the example deployment. For this deployment, allocate at least 5GB of memory.

For more information about modifying the resources allocated to Docker, see:
- [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/#resources)
- [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/#resources)


### <a name="commandlinetools"></a> Command Line Tools

You must install `jq` command line tools into your shell. For more information, see [Download jq](https://stedolan.github.io/jq/download/).

For example, on *WSL* with Ubuntu kernel:
```sh
sudo apt-get update
sudo apt-get install jq
```

### <a name="visualstudiocode"></a> Visual Studio Code

The repository is designed to be used with VS Code to create the development environment.

- Download and install [VS Code](https://code.visualstudio.com/download)

To make the environment easier to use, install the following extensions in VS Code:  
- [Remote - WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
- [Docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker)
- [Shellcheck](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)
- [Bash IDE](https://marketplace.visualstudio.com/items?itemName=mads-hartmann.bash-ide-vscode)
- [Red Hat XML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-xml)
- [Red Hat YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

### <a name="i2analyzeminimaltoolkit"></a> i2 Analyze minimal toolkit

1. Download the i2 Analyze V4.3.3 Fix Pack 1 Minimal archive for Linux package from the IBM i2 Enterprise Insight Analysis 2.3.4 Fix Pack 1 on Fix Central: [Fix Central](https://www.ibm.com/support/fixcentral/swg/identifyFixes?query.parent=i2&query.product=ibm~Other%20software~i2%20Enterprise%20Insight%20Analysis&query.release=2.3.4.0&query.platform=All).
1. Rename the `IBM_i2_Analyze_4.3.3_Fix_Pack_1_Linux_Minimal_Archive.tar.gz` file to `i2analyzeMinimal.tar.gz`, then copy it to the `Analyze-Containers/pre-reqs` directory.

### <a name="jdbcdrivers"></a> JDBC drivers

You must provide the JDBC driver to enable the application to communicate with the database.

For SQL Server, copy the `mssql-jdbc-7.4.1.jre8.jar` file to the `Analyze-Containers/pre-reqs/jdbc-drivers` directory.

You can download the Microsoft JDBC Driver 7.4 for SQL Server archive from https://www.microsoft.com/en-us/download/details.aspx?id=58505. Extract the contents of the download, and locate the `sqljdbc_7.4\enu\mssql-jdbc-7.4.1.jre8.jar` file.

---

## <a name="creatingacontaineriseddeployment"></a> Creating a containerised deployment

After you have all of the prerequisites in place, use the example scripts and artifacts in the `environments/pre-prod` directory to create the reference pre-production containerised deployment.

### <a name="creatingtheenvironmentandconfiguration"></a> Creating the environment and configuration

The `createEnvironment.sh` script performs a number of actions that ensure all of the artifacts for a deployment are created and in the correct locations. These actions include:
- Extracting the i2 Analyze minimal toolkit to the `pre-reqs/i2analyze` directory.
- Creating the i2 Analyze Liberty application
- Creating and populating the configuration directory structure

For more information about the what the script does, see:
- [Create environment](./tools%20and%20functions/create_environment.md)
- [Create configuration](./tools%20and%20functions/create_configuration.md)

To create the environment and configuration, run the following commands:
```
./createEnvironment.sh
./createConfiguration.sh
```

The `configuration` directory is created in the `environments/pre-prod` directory.

By default, the environment is created for an Information Store and i2 Connect gateway deployment.

### <a name="acceptingthelicences"></a> Accepting the licences

- Before you can use i2 Analyze and the tools, you must read and accept the licence agreement and copyright notices in the `pre-reqs/i2analyze/license` directory.  
    To accept the licence agreement, change the value of the `LIC_AGREEMENT` environment variable to `ACCEPT`. The environment variable is in the `utils/commonVariables.sh` script.

- Before you can use Microsoft SQL Server, you must accept the licence agreement and the EULA. For more information about using the `MSSQL_PID` and `ACCEPT_EULA` environment variables, see [Configure SQL Server settings with environment variables on Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15#environment-variables)  
    To accept the licence in this environment, change the value of the `MSSQL_PID` and `ACCEPT_EULA` environment variables. The environment variable is in the `utils/commonVariables.sh` script.

### <a name="buildingthedockerimages"></a> Building the Docker images

To build the Docker images, run the following command:
```
./buildImages.sh 
```

### <a name="generatingthesecrets"></a> Generating the secrets

To generate the secrets used in the environment, run the following command:
```
./generateSecrets.sh
```

For more information about the secrets that are generated and how they are used, see [Managing secrets](./security%20and%20users/security.md).

### <a name="runningthecontainersandstarti2analyze"></a> Running the containers and start i2 Analyze

To deploy and start i2 Analyze, run the following command:
```
./deploy.sh
```

For more information about the actions that are completed, see [Deploying i2 Analyze](./tools%20and%20functions/deploy.md).

### <a name="modifyingthehostsfile"></a> Modifying the hosts file

To enable you to connect to the deployment and the Solr Web UI, update your hosts file to include the following lines:
```
127.0.0.1 solr1.eia
127.0.0.1 i2analyze.eia
```
>NOTE: On Windows, you must edit your hosts file in `C:\Windows\System32\drivers\etc` and the hosts file in `/etc/hosts` for WSL.

---

## <a name="installingcertificate"></a> Installing Certificate

To access the system, the server that you are connecting from must trust the certificate that it receives from the deployment. To enable trust, install the `environments/pre-prod/generated-secrets/certificates/externalCA/CA.cer` certificate as a trusted root certificate authority in your browser and operating system's certificate store.

For information about installing the certificate, see:
- [Install Certificates with the Microsoft Management Console](https://windowsreport.com/install-windows-10-root-certificates/#2)
- [Setting up certificate authorities in Firefox](https://support.mozilla.org/en-US/kb/setting-certificate-authorities-firefox)
- [Set up an HTTPS certificate authority in Chrome](https://support.google.com/chrome/a/answer/6342302?hl=en)

## <a name="accessingthesystem"></a> Accessing the system

To connect to the deployment, the URL to use is: `https://i2analyze.eia:9046/opal/`

## <a name="whattodonext"></a> What to do next

To understand how the environment is created, you can review the documentation that explains the images, containers, tools, and functions:
- [Images and containers](./images%20and%20containers/)
- [Tools and functions](./tools%20and%20functions/)

To learn how to configure and administer i2 Analyze in a containerised environment, you can complete the walkthroughs that are included in the repository:
- [Walkthroughs](./walkthroughs/walkthroughs.md)
