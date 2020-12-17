# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
FROM ibmcom/websphere-liberty:full-java8-openj9-ubi

# Copy server.datasource-db2.xml & server.datasource-sqlserver.xml
COPY --chown=1001:0 application/server.datasources.db2.xml /opt/ibm/wlp/usr/servers/defaultServer/db2.xml
COPY --chown=1001:0 application/server.datasources.sqlserver.xml /opt/ibm/wlp/usr/servers/defaultServer/sqlserver.xml

# Copy optional ssl configuration
COPY --chown=1001:0 application/server.ssl.xml /opt/ibm/wlp/usr/servers/defaultServer/true.xml

# Copy third party dependencies
COPY --chown=1001:0 application/third-party-dependencies /opt/ibm/wlp/usr/shared/

# Copy application
COPY --chown=1001:0 application/opal-services/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/

# Copy web.xml & ibm-web-bnd.xml
COPY --chown=1001:0 application/web-app-files/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/

# Copy liberty server configuration files
COPY --chown=1001:0 application/server-config/ /opt/ibm/wlp/usr/servers/defaultServer/

COPY --chown=1001:0 docker-entrypoint.sh /opt/docker-entrypoint.sh 
COPY --chown=1001:0 environment.sh /opt/environment.sh

ENV APOLLO_DATA_DIR=/data

USER root
RUN mkdir ${APOLLO_DATA_DIR} \
    && chmod -R g+rw ${APOLLO_DATA_DIR} \
    && chown -R 1001:0 ${APOLLO_DATA_DIR}
    
USER 1001

VOLUME ${APOLLO_DATA_DIR}

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]
