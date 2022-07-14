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

set -e

. /opt/db-scripts/environment.sh
. /opt/db-scripts/commonFunctions.sh

file_env 'DB2INST1_OLD_PASSWORD'
file_env 'DB2INST1_NEW_PASSWORD'

catalogRemoteNode

# NOTE: This script changes the initial db2inst1 password ("${DB2INST1_OLD_PASSWORD}"),
# and due to this we cannot use the function 'runSQLQuery' in the
# 'commonFunctions.sh' script to execute the SQL Query, as 'commonFunctions.sh'
# relies on the password this script sets.
runSQLCMD "ATTACH TO \"${DB_NODE}\" USER \"${DB2INST1_USERNAME}\" USING \"${DB2INST1_OLD_PASSWORD}\" NEW \"${DB2INST1_NEW_PASSWORD}\" CONFIRM \"${DB2INST1_NEW_PASSWORD}\""

set +e
