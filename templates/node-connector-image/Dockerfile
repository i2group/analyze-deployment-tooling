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

FROM registry.access.redhat.com/ubi8/nodejs-14

USER 0

COPY --chown=1001:0 docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=1001:0 environment.sh /opt/environment.sh

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available
COPY app/package*.json ./

# Node image comes with a non-root node user. Lets avoid running the connector
# as root. It is a recommended security practise to avoid running containers as root

# Sets the user to be 1001. This user will be used for all subsquent commands
USER 1001

# Install our dependencies
RUN npm install

# Copy our application code with the appropriate permissions
COPY --chown=1001:0 app/ .

# Expose the port the connector will use
EXPOSE 3700

# The lifecycle of the connector will be attached to node app
ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD [ "node", "app.js" ]