# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM i2group/i2eng-solr:8.11
ARG I2ANALYZE_VERSION

LABEL com.i2group.i2analyze-version="${I2ANALYZE_VERSION}"

# i2 jars for extending Solr
COPY --chown=0:0 jars/solr-data /opt/i2-plugin/lib
# Example to copy a custom solr.xml
# COPY --chown=0:0 solr.xml /var/solr/data/solr.xml
