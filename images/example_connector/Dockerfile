# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM registry.access.redhat.com/ubi8/nodejs-14:1
LABEL maintainer="i2 Group"
USER 0

WORKDIR ${HOME}
COPY --chown=1001:0 docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=1001:0 environment.sh /opt/environment.sh

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available
COPY app/package*.json ./

# Install our dependencies
RUN npm install

# Node image comes with a non-root node user. Lets avoid running the connector
# as root. It is a recommended security practice to avoid running containers as root

# Sets the user to be 1001. This user will be used for all subsequent commands
USER 1001

# Copy our application code with the appropriate permissions
COPY --chown=1001:0 app/ .

# Expose the port the connector will use
EXPOSE 3000 3443

ENV PORT=3443

# The lifecycle of the connector will be attached to node app
ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD [ "node", "app.js" ]