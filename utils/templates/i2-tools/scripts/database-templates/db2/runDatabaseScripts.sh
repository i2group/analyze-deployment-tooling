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

if [ -z "${1}" ];
then
  echo "You need to set the path to the scripts."
  exit 1
fi

db2 "CATALOG TCPIP node \"${DB_NODE}\" REMOTE \"${DB_SERVER}\" SERVER \"${DB_PORT}\""
db2 "CATALOG DATABASE \"${DB_NAME}\" at node \"${DB_NODE}\""

find "${1}" -maxdepth 1 -type f | sort | while read -r file_name; do
  db2 "CONNECT TO \"${DB_NAME}\" USER \"${DB_USERNAME}\" USING \"${DB_PASSWORD}\""
  db2 -tvmsf "${file_name}"
done

set +e
