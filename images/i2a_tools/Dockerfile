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
FROM adoptopenjdk/openjdk11:ubi-jre
LABEL maintainer="i2 Group"
ARG USERNAME=i2analyze
ARG USER_UID
ARG USER_GID=$USER_UID

RUN useradd $USERNAME

RUN groupmod --gid $USER_GID $USERNAME \
    && usermod --uid $USER_UID --gid $USER_GID $USERNAME \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME
 
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh
COPY tools/ /opt/

RUN mkdir -p /opt/configuration \
  && mkdir -p /opt/databaseScripts/generated \
  && chown -R $USER_UID:$USER_GID /opt/environment.sh \
    /opt/docker-entrypoint.sh \
    /opt/i2-tools/* \
    /opt/scripts/* \
    /opt/configuration \
    /opt/databaseScripts/generated
    
ENV TOOLKIT_DIR=/opt

USER $USERNAME

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
