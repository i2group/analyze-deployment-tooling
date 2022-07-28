# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM mcr.microsoft.com/mssql/rhel/server:2019-CU11-rhel-8.3

USER root
# User mssql is created by the base image
ARG USER=mssql

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" environment.sh /opt/environment.sh
RUN mkdir -p /run/secrets /backup /var/i2a-data \
  && chown -R "${USER}" /var/opt/mssql /tmp /run/secrets /backup /var/i2a-data

USER "${USER}"

ENTRYPOINT ["/opt/mssql/bin/permissions_check.sh", "/opt/docker-entrypoint.sh"]
CMD ["/opt/mssql/bin/sqlservr"]
