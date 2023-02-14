#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

# if user not root ensure to give correct permissions before start
if [ -n "$GROUP_ID" ] && [ "$GROUP_ID" != "0" ]; then
  if [ "$(getent group "${SOLR_USER}")" ]; then
    groupmod -g "$GROUP_ID" "${SOLR_USER}" >/dev/null
  else
    groupadd -g "$GROUP_ID" "${SOLR_USER}" >/dev/null
  fi
  usermod -u "$USER_ID" -g "$GROUP_ID" "${SOLR_USER}" >/dev/null
fi

chown -R "$SOLR_USER:0" /var/solr /opt/solr/example /backup
chown "$SOLR_USER:0" /opt/solr/server/resources/log4j2-console.xml

set +e
# Call solr default entrypoint
exec /usr/local/bin/gosu "${SOLR_USER}" /opt/docker-solr/scripts/docker-entrypoint.sh "$@"
