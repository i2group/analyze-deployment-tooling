# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM registry.access.redhat.com/ubi8/nodejs-16:1

LABEL maintainer="i2 Group"
USER 0

WORKDIR ${HOME}
ENV NODE_ENV=production

EXPOSE 3000 3443

# Install app dependencies
# We want to install all the latest dependencies at the time of building the image
# This requires that the package-lock.json file is not present.
COPY app/package.json ./

# Install our dependencies
RUN npm install

# Node image comes with a non-root node user. Lets avoid running the connector
# as root. It is a recommended security practice to avoid running containers as root

# Sets the user to be 1001. This user will be used for all subsequent commands
USER 1001

# Copy our application code with the appropriate permissions
COPY --chown=1001:0 app/ .

# The lifecycle of the connector will be attached to node app
CMD [ "npm", "run", "serve" ]
