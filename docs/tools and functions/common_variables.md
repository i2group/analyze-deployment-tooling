# Common Variables

All scripts in the containerised environment use variables to configure the system such as location of file paths, host names, port etc

These variables are all stored in a central script in `environments/pre-prod/utils/commonVariables.sh` script.

The following descriptions explains the variables in the `createVariables.sh` script in more detail.

## License Variables  

This section contains the license variables that are used by the containers. These variables must be accepted before running the system.

## Network Security Variables 

This section contains the variables to turn on or off SSL. For more information about switching SSL on or off see the image and containers section or secrets section

## Ports

This section contains the variables for all the ports that are exposed on the containers.

## Connection Information

This section contains connection variables such as the Zookeeper hosts that are used by various containers

## Localisation variables

This section contains the localisation variables. These variables are used by the `createConfiguration.sh` script to set up the configuration in the correct locale.

## Image names

This section contains the image names for all the images built by the buildImages.sh script. These variables are also used by the `clientFunctions.sh` and `severFunctions.sh` scripts.

## Image names

This section contains the container names for all the containers run in the environment.

## Volume names

This section contains the volume names for all the volumes used by the containers run in the environment.

## User names  

This section contains all the usernames used by the servers in the containerised environment.

## Container secrets paths

This section contains variables for the container secrets and certificate directories. For more information about these variables see the secrets section.

## Security configuration

This section contains security variables used by the `generateSecrets.sh` scripts. For example the duration or the certificate or the certificate key size.

## Database variables

This section contains database connection variables, database paths, os type and other database related variables used by the scripts.


## Path variables

The section contains the various paths in the environment that are used by the scripts.

## Front end URI

This section contains the variable for the front end URI.