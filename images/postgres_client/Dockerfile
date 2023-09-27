# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="i2group/i2eng-postgres:15"
FROM ${BASE_IMAGE}

ARG GOSU_VERSION=1.16

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" db-scripts/ /opt/db-scripts
COPY --chown="${USER}:0" tools/ /opt/

ENV TOOLKIT_DIR=/opt

# Change to root to install necessary packages
# hadolint ignore=DL3002
USER root

RUN apt-get update \
  && apt-get install -y curl \
  && rm -rf /var/lib/apt/lists/* \
  && ARCH="$(uname -m)" \
  && if [ "${ARCH}" != "aarch64" ]; then \
  curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"; \
  else curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64"; fi \
  && chmod +x /usr/local/bin/gosu \
  # Verify that the binary works
  && gosu nobody true \
  && mkdir -p /opt/databaseScripts/generated /opt/customDatabaseScripts /opt/toolkit /etc/pki /tmp/i2acerts \
  && chown -R ${USER} /opt/databaseScripts/generated \
  /opt/customDatabaseScripts \
  /opt/toolkit \
  /etc/pki \
  /tmp/i2acerts \
  && ln -s /usr/lib/postgresql/${VERSION}/bin /usr/lib/postgresql/bin

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
