# Managing container security

## <a name="sslcertificatesinthedeployment"></a> SSL certificates in the deployment

The example deployment is configured to use SSL connections for communication between clients and i2 Analyze, and between the components of i2 Analyze.

To achieve this, the appropriate certificate authorities and certificates are used. The `generateSecrets.sh` script is used to simulate the process of creating the required keys and acquiring certificate authority-signed certificates.

> Note: The keys and certificates used are set to expire after 90 days. To use the certificates for longer than this, you must run the `generateSecrets.sh` script again.

## <a name="certificateauthorities"></a> Certificate Authorities (CA)

In the example, two CAs are used to provide trust:

- **Internal CA**
   The internal CA is to provide trust for the containers that are used for the components of i2 Analyze. Each container's certificates are signed by the internal CA.
- **External CA**
   The external CA is to provide trust for external requests to the i2 Analyze service via the load balancer. In our example, the external certificate authority is generated for you. However, in production a real certificate should be used.

## <a name="containercertificates"></a> Container certificates

To communicate securely using SSL each container requires the following certificates:

- private key
- certificate key
- internal certificate authority

The containers will generate truststores and keystores based on the keys provided to the container. For more information about how the keys are passed to the containers securely please see [Secure Environment variables](#secureenvironmentvariables).

## <a name="securecommunicationbetweencontainers"></a> Secure communication between containers

When the components communicate, the `CA certificate` is used to establish trust of the `container certificate` that is received.  

- Each container has its own private key

- ZooKeeper requires client authentication to initiate communication. The i2 Analyze, i2 Analyze Tool, and Solr client containers require container certificates to authenticate with ZooKeeper.

## <a name="creatingkeysandcertificates"></a> Creating keys and certificates
The following diagram shows a simplified sequence of creating a container certificate from the certificate authority and using it to establish trust:


1. The certificate authority's certificate is distributed to the client.

1. The private key is generated on the server.  
   In the `generateSecrets.sh` script, the key is created by: 
   ```bash
   openssl genrsa -out server.key 4096
   ```

1. The public part of the private key is used in a Certificate Signing Request (CSR).  
   In the `generateSecrets.sh` script, this is completed by:
   ```bash
   openssl req -new -key server.key -subj "/CN=solr1.eia" -out key.csr
   ```
   The common name that is used for the certificate is the server's fully qualified domain name.  
   The CSR is sent to the certificate authority (CA). 

1. The CA signs and returns a signed certificate for the server.  
   In the `generateSecrets.sh` script, the CA signing the certificate is completed by:
   ```bash
   openssl x509 -req -sha256 -CA CA.cer -CAkey CA.key -days 90 -CAcreateserial -CAserial CA.srl -extfile x509.ext -extensions "solr" -in key.csr -out server.cer
   ```

1. When communication is established, the `container certificate` is sent to the client. The client uses it's copy of the `CA certificate` to verify that the `container certificate` was signed by the same CA. 

## <a name="passwordgeneration"></a> Password generation

The example simulates secrets management performed by various secrets managers provided by cloud vendors. The `generateSecrets.sh` generates these secrets and populates the `environments/pre-prod/simulated-secret-store` with secrets required for each container. The docker desktop does not support secrets, but the example environment example simulates this by mounting the secrets folder. For more information see [Manage sensitive data with Docker secrets](https://docs.docker.com/engine/swarm/secrets/).

After these passwords have been generated, they can be uploaded to a secrets manager. Alternatively you can use a secrets manager to generate your passwords.

## <a name="solrbasicauthentication"></a> Solr Basic Authentication

Solr authorisation can be enabled using the BasicAuthPlugin. The basic auth plugin defines users, user roles and passwords for users. For the BasicAuthPlugin to be enabled, solr requires a security.json file to be uploaded. In our example the security.json file is created by the `generateSecrets.sh` and located in `environments/pre-prod/generatedSecrets/secrets/solr/security.json`.

For more information about solr authentication see [Basic Authentication Plugin](https://lucene.apache.org/solr/guide/8_3/basic-authentication-plugin.html)

## <a name="secureenvironmentvariables"></a> Secure Environment variables

In general secrets used by a particular container can be supplied via an environment variable containing the path to a file containing the secret, or an environment variable specifying the literal secret value, for example:
Note: Secrets can be passwords, keys or certificates.

```bash
docker run --name solr1 -d --net eia
  --secret source=SOLR_SSL_KEY_STORE_PASSWORD,target=SOLR_SSL_KEY_STORE_PASSWORD \
  -e SOLR_SSL_KEY_STORE_PASSWORD_FILE="/run/secrets/SOLR_SSL_KEY_STORE_PASSWORD_FILE"
```
or
```bash
docker run --name solr1 -d --net eia
  -e SOLR_SSL_KEY_STORE_PASSWORD="jhga98u43jndfj"
```

The docker files in the `Analyze-Containers` repository have been modified to accept either. The convention is that the environment variable must match the property being set with "_file" appended if the secret is in a file, and without if a literal value is being used instead.

In the example scripts, each container gets the relevant key stores mounted along with the correct secrets files in a secrets directory.

**NOTE:** By default this is set as `CONTAINER_SECRETS_DIR="/run/secrets"` in the common variables file.

All the containers use the same environment variables to define the location of certificates. These are then used to generate appropriate artifacts for the particular container. There is also a standard way of turning on and off server SSL.

Security switching variables

| Environment variable              | Description |
| --------------------------------- | ----------- |
| `SERVER_SSL`                      | Can be set to `true` or `false`. If set to `true`, connections to the container use an encrypted connection. |
| `GATEWAY_SSL_CONNECTION`          | Can be set to `true` of `false`. If set to `true`, connections to i2 Connect connectors use an encrypted connection. |
| `DB_SSL_CONNECTION`               | Can be set to `true` or `false`. If set to `true`, connections to the database use an encrypted connection |
| `SOLR_ZOO_SSL_CONNECTION`         | Can be set to `true` or `false`. If set to `true`, connections to ZooKeeper and Solr use an encrypted connection. |

Security environment variables

| Environment variable              | Description |
| --------------------------------- | ----------- |
| `SSL_PRIVATE_KEY`                 | The private key for the container certificate. |
| `SSL_CERTIFICATE`                 | The container certificate. |
| `SSL_CA_CERTIFICATE`              | The Certificate Authority certificate. |
| `SSL_OUTBOUND_PRIVATE_KEY`        | The private key for the Liberty container, which is used for outbound connections. |
| `SSL_OUTBOUND_CERTIFICATE`        | The private certificate for the Liberty container, which is used for outbound connections. |
