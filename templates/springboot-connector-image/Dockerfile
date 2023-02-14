# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG SPRINGBOOT_BASE_IMAGE="eclipse-temurin:11-ubi9-minimal"
FROM ${SPRINGBOOT_BASE_IMAGE}

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh

WORKDIR /
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

# Expose the port the connector will use
EXPOSE 3000 3443

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["java","-jar","/app.jar"]
