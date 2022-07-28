# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM ibmcom/db2:11.5.6.0

LABEL maintainer="i2 Group"
# hadolint ignore=DL3002
USER root

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh
COPY pam.d/db2 /etc/pam.d/db2

RUN mkdir /var/custom
COPY setup-db.sh /var/custom
RUN chmod a+x /var/custom/setup-db.sh

ENTRYPOINT ["/opt/docker-entrypoint.sh"]