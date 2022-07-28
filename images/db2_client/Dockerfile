# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM ibmcom/db2:11.5.6.0

LABEL maintainer="i2 Group"
USER root

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY db-scripts/ /opt/db-scripts
COPY tools/ /opt/

ENV TOOLKIT_DIR=/opt

RUN yum update -y \
  && yum install -y \
  ca-certificates \
  && yum clean all

RUN mkdir -p /opt/databaseScripts/generated \
  && mkdir -p /opt/toolkit \
  && groupadd db2iadm1 \
  && groupadd db2fadm1 \
  && useradd -m -g db2iadm1 db2inst1 \
  && useradd -g db2fadm1 db2fenc1 \
  && usermod -aG wheel db2inst1 \
  && chmod 755 /home/db2inst1

RUN retry=0; while true; do (/opt/ibm/db2/V11.5/instance/db2icrt -s client db2inst1) && break || if [ $retry -lt 5 ]; then retry=$((retry+1)); sleep 3; else exit 1; fi done

# Set the global registry values
RUN /opt/ibm/db2/V11.5/instance/db2iset -g DB2SYSTEM=db2client \
  && /opt/ibm/db2/V11.5/instance/db2iset -g DB2INSTDEF=db2inst1 \
  && /opt/ibm/db2/V11.5/instance/db2iset -g DB2COMM=TCPIP,SSL

# Update DB2 registry and DBM cfg settings
USER db2inst1
RUN /opt/ibm/db2/V11.5/adm/db2set DB2SYSTEM=db2client
# hadolint ignore=DL3002
USER root

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
