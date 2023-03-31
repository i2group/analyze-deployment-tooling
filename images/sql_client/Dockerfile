# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="mcr.microsoft.com/mssql/rhel/server:2019-CU18-rhel-8.5"
FROM "${BASE_IMAGE}"

# Change to root to install necessary packages
# hadolint ignore=DL3002
USER root

# User mssql is created by the base image
ARG USERNAME=mssql
ARG GOSU_VERSION=1.14

RUN ACCEPT_EULA=Y yum update -y --nobest \
  mssql-tools \
  && yum install -y \
  ca-certificates \
  && yum clean all \
  && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
  && chmod +x /usr/local/bin/gosu \
  # Verify that the binary works
  && gosu nobody true

COPY --chown="${USERNAME}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USERNAME}:0" db-scripts/ /opt/db-scripts
COPY --chown="${USERNAME}:0" tools/ /opt/

ENV TOOLKIT_DIR=/opt \
  USER="${USERNAME}"

RUN mkdir -p /opt/databaseScripts/generated /opt/customDatabaseScripts /opt/toolkit /tmp/i2acerts \
  && chown -R ${USERNAME} /opt/databaseScripts/generated \
  /opt/customDatabaseScripts \
  /opt/toolkit \
  /etc/pki

ENTRYPOINT ["/opt/docker-entrypoint.sh"]