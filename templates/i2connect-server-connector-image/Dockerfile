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

FROM registry.access.redhat.com/ubi8/nodejs-14:1

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
