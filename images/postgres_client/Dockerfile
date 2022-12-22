# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="i2group/i2eng-postgres:15"
FROM ${BASE_IMAGE}

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" db-scripts/ /opt/db-scripts
COPY --chown="${USER}:0" tools/ /opt/

ENV TOOLKIT_DIR=/opt

USER root

RUN mkdir -p /opt/databaseScripts/generated \
  && mkdir -p /opt/toolkit /etc/pki \
  && chown -R ${USER} /opt/databaseScripts/generated \
  /opt/toolkit \
  /etc/pki \
  && ln -s /usr/lib/postgresql/${VERSION}/bin /usr/lib/postgresql/bin

USER "${USER}"

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
