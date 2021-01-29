# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

FROM mcr.microsoft.com/mssql/rhel/server:2019-CU1-rhel-8

USER root

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY db-scripts/ /opt/db-scripts
COPY tools/ /opt/

ENV TOOLKIT_DIR=/opt

RUN yum install -y ca-certificates
RUN ACCEPT_EULA=Y yum update -y mssql-tools

RUN mkdir -p /opt/databaseScripts/generated
RUN mkdir -p /opt/toolkit

ENTRYPOINT ["/opt/docker-entrypoint.sh"]