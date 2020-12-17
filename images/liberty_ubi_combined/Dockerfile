# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Copy classes configuration into liberty image
COPY --chown=1001:0 classes/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/classes/
COPY --chown=1001:0 server.extensions.xml /opt/ibm/wlp/usr/servers/defaultServer
COPY --chown=1001:0 user.registry.xml /opt/ibm/wlp/usr/shared/config/user.registry.xml
