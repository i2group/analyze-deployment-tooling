#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

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
