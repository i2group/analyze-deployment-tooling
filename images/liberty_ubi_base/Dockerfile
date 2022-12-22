# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="i2group/i2eng-liberty:ubi"

FROM ${BASE_IMAGE}
ARG I2ANALYZE_VERSION

LABEL com.i2group.i2analyze-version="${I2ANALYZE_VERSION}"

# Copy server datasource xml
COPY --chown=1001:0 application/server.datasources.db2.xml /config/db2.xml
COPY --chown=1001:0 application/server.datasources.sqlserver.xml /config/sqlserver.xml
COPY --chown=1001:0 application/server.datasources.postgres.xml /config/postgres.xml

# Copy optional ssl configuration
COPY --chown=1001:0 application/server.ssl.xml /config/true.xml

# Copy jvm.options
COPY --chown=1001:0 application/jvm.options /config/jvm.options

# Copy third party dependencies
COPY --chown=1001:0 application/third-party-dependencies /liberty/usr/shared/

# Copy application
COPY --chown=1001:0 application/opal-services/ /config/apps/opal-services.war/

# Copy web.xml & ibm-web-bnd.xml
COPY --chown=1001:0 application/web-app-files/ /config/apps/opal-services.war/WEB-INF/

# Copy liberty server configuration files
COPY --chown=1001:0 application/server-config/ /config/

COPY --chown=1001:0 create-connector-config /opt/entrypoint.d/create-connector-config

ENV APOLLO_DATA_DIR="/data"

USER root

RUN mkdir "${APOLLO_DATA_DIR}"  \
  && chmod -R g+rw "${APOLLO_DATA_DIR}" \
  && chown -R 1001:0 "${APOLLO_DATA_DIR}"

USER 1001

VOLUME "${APOLLO_DATA_DIR}"
