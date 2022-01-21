#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022, N. Harris Computer Corporation
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

# Controls they deployment pattern. Possible values are: istore | i2c | cstore | i2c_istore | i2c_cstore | schema_dev
DEPLOYMENT_PATTERN=""

# The port that you use to connect to the Solr Web UI from the host machine.
HOST_PORT_SOLR="8983"

# The port that you use to connect to the deployment from the host machine.
HOST_PORT_I2ANALYZE_SERVICE="9443"

# The port that you use to connect to the database from the host machine. Use "1433" for SQL Server
HOST_PORT_DB="1433"

# Controls the database dialect. Possible values are: sqlserver
DB_DIALECT="sqlserver"