# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
FROM i2group/i2eng-liberty:22
ARG I2ANALYZE_VERSION

LABEL com.i2group.i2analyze-version="${I2ANALYZE_VERSION}"

# Copy server.datasource-db2.xml & server.datasource-sqlserver.xml
COPY --chown=1001:0 application/server.datasources.db2.xml /opt/ibm/wlp/usr/servers/defaultServer/db2.xml
COPY --chown=1001:0 application/server.datasources.sqlserver.xml /opt/ibm/wlp/usr/servers/defaultServer/sqlserver.xml

# Copy optional ssl configuration
COPY --chown=1001:0 application/server.ssl.xml /opt/ibm/wlp/usr/servers/defaultServer/true.xml

# Copy jvm.options
COPY --chown=1001:0 application/jvm.options /opt/ibm/wlp/usr/servers/defaultServer/jvm.options

# Copy third party dependencies
COPY --chown=1001:0 application/third-party-dependencies /opt/ibm/wlp/usr/shared/

# Copy application
COPY --chown=1001:0 application/opal-services/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/

# Copy web.xml & ibm-web-bnd.xml
COPY --chown=1001:0 application/web-app-files/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/

# Copy liberty server configuration files
COPY --chown=1001:0 application/server-config/ /opt/ibm/wlp/usr/servers/defaultServer/

COPY --chown=1001:0 create-connector-config.sh /opt/entrypoint.d/create-connector-config.sh 

ENV APOLLO_DATA_DIR=/data

USER root

RUN mkdir ${APOLLO_DATA_DIR} \
  && chmod -R g+rw ${APOLLO_DATA_DIR} \
  && chown -R 1001:0 ${APOLLO_DATA_DIR}

USER 1001

VOLUME ${APOLLO_DATA_DIR}
