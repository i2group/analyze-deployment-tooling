#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

STATE=0

# Possible states:
#    0 = create hasn't been run
#    1 = prometheus & grafana & zk & solr cluster created successfully
#    2 = db created successfully
#    3 = i2 analyze started with errors
#    4 = i2 analyze started up successfully
