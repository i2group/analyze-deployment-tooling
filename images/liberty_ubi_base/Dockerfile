# MIT License
#
# Copyright (c) 2021, IBM Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
FROM ibmcom/websphere-liberty:full-java11-openj9-ubi

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

COPY --chown=1001:0 docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=1001:0 create-connector-config.sh /opt/create-connector-config.sh 
COPY --chown=1001:0 environment.sh /opt/environment.sh

ENV APOLLO_DATA_DIR=/data

USER root
RUN yum -y install jq

RUN mkdir ${APOLLO_DATA_DIR} \
    && chmod -R g+rw ${APOLLO_DATA_DIR} \
    && chown -R 1001:0 ${APOLLO_DATA_DIR}
    
USER 1001

VOLUME ${APOLLO_DATA_DIR}

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]
