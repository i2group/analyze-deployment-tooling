# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM mcr.microsoft.com/mssql/rhel/server:2019-CU16-rhel-8.5

# Change to root to install necessary packages
USER root
RUN ACCEPT_EULA=Y yum update -y --nobest \
  mssql-tools \
  && yum install -y \
  ca-certificates \
  && yum clean all

# User mssql is created by the base image
ARG USER=mssql

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" db-scripts/ /opt/db-scripts
COPY --chown="${USER}:0" tools/ /opt/

ENV TOOLKIT_DIR=/opt

RUN mkdir -p /opt/databaseScripts/generated \
  && mkdir -p /opt/toolkit \
  && chown -R ${USER} /opt/databaseScripts/generated \
  /opt/toolkit \
  /etc/pki

USER "${USER}"

ENTRYPOINT ["/opt/docker-entrypoint.sh"]