#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

# Controls they deployment pattern. Possible values are: istore | i2c | cstore | i2c_istore | i2c_cstore | schema_dev
DEPLOYMENT_PATTERN=""

# The port that you use to connect to the Solr Web UI from the host machine.
HOST_PORT_SOLR="8983"

# The port that you use to connect to the deployment from the host machine.
HOST_PORT_I2ANALYZE_SERVICE="9443"

# The port that you use to connect to the database from the host machine. Use "1433" for SQL Server.
HOST_PORT_DB="1433"

# Controls the database dialect. Possible values are: sqlserver
DB_DIALECT="sqlserver"

# The port that you use to connect to the Prometheus UI from the host machine.
HOST_PORT_PROMETHEUS="9090"

# The port that you use to connect to the Grafana UI from the host machine.
HOST_PORT_GRAFANA="3500"
