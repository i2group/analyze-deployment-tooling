# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0

FROM node:12


COPY --chown=node:node docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=node:node environment.sh /opt/environment.sh

# Node image comes with a non-root node user. Lets avoid running the connector
# as root. It is a recommended security practise to avoid running containers as root

# Lets create the node_modules and set the ownership on them to our node user
# to fine tune the permissions on our connector.
RUN mkdir -p /home/node/app/node_modules && chown -R node:node /home/node/app

WORKDIR /home/node/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available
COPY app/package*.json ./

# Sets the user to be node. Node user will be used for all subsquent commands
USER node

# Install our dependencies
RUN npm install

# Copy our application code with the appropriate permissions
COPY --chown=node:node app/ .

# Expose the port the connector will use
EXPOSE 3700

# The lifecycle of the connector will be attached to node app
ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD [ "node", "app.js" ]