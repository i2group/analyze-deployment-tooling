# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="i2group/i2eng-solr:8.11"
FROM "${BASE_IMAGE}"
ARG I2ANALYZE_VERSION

LABEL com.i2group.i2analyze-version="${I2ANALYZE_VERSION}"

ARG GOSU_VERSION=1.14

# Change to root to install necessary packages
# hadolint ignore=DL3002
USER root

RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
  && chmod +x /usr/local/bin/gosu \
  # Verify that the binary works
  && gosu nobody true \
  && mkdir -p /backup \
  && chown -R "${SOLR_USER}:0" /backup

# COPY docker-entrypoint.sh /opt/docker-entrypoint.sh

# i2 jars for extending Solr
COPY --chown="${SOLR_USER}:0" jars/solr-data /opt/i2-plugin/lib
# Example to copy a custom solr.xml
# COPY --chown=0:0 solr.xml /var/solr/data/solr.xml

# ENTRYPOINT ["/opt/docker-entrypoint.sh"]
# CMD ["solr-foreground"]
USER ${SOLR_USER}