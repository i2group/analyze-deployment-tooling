#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2021, IBM Corporation
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

# Enable ATS
su - db2inst1 -c "db2set DB2_ATS_ENABLE=YES"

# Set port number as the service
su - db2inst1 -c "db2 update dbm cfg using SVCENAME 50000"

# Set authentication
su - db2inst1 -c "db2set DB2AUTH=OSAUTHDB"

# Create i2a-data dir and set permissions
mkdir -p /var/i2a-data
chown -R db2inst1:db2iadm1 /var/i2a-data

# Restart and update instance
su - db2inst1 -c "db2stop"
/opt/ibm/db2/V11.5/instance/db2iupdt db2inst1
su - db2inst1 -c "db2start"
