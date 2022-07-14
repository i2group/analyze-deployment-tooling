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
ARG BASE_IMAGE=liberty_redhat
FROM ${BASE_IMAGE}

# Copy classes configuration into liberty image
COPY --chown=1001:0 classes/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/classes/
COPY --chown=1001:0 server.extensions*.xml /opt/ibm/wlp/usr/servers/defaultServer/
COPY --chown=1001:0 user.registry.xml /opt/ibm/wlp/usr/shared/config/user.registry.xml
COPY --chown=1001:0 application/web-app-files/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/

# Copy libs into liberty image
COPY --chown=1001:0 lib/ /opt/ibm/wlp/usr/servers/defaultServer/apps/opal-services.war/WEB-INF/lib/