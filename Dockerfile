ARG DEBIAN_VERSION
FROM --platform=linux/x86_64 aptible/debian:${DEBIAN_VERSION}

ENV INFLUXDB_USER influxdb
ENV INFLUXDB_GROUP influxdb

RUN groupadd -r "$INFLUXDB_GROUP" \
 && useradd -r -g "$INFLUXDB_GROUP" "$INFLUXDB_USER"

ARG INFLUXDB_VERSION
ENV INFLUXDB_VERSION ${INFLUXDB_VERSION}
ARG INFLUXDB_DEB_SHA256
ENV INFLUXDB_DEB_SHA256 ${INFLUXDB_DEB_SHA256}

ADD script /script
ARG INFLUXDB_INSTALL_METHOD
ENV INFLUXDB_INSTALL_METHOD ${INFLUXDB_INSTALL_METHOD}
RUN /script/install-influxdb-$INFLUXDB_INSTALL_METHOD.sh

RUN apt-install pwgen sudo

ENV DATA_DIRECTORY /var/db
ENV PORT 8086

RUN mkdir "$DATA_DIRECTORY" \
 && chown -R "${INFLUXDB_USER}:${INFLUXDB_GROUP}" "$DATA_DIRECTORY"

VOLUME ["$DATA_DIRECTORY"]
EXPOSE "$PORT"

ADD template /template
ADD bin /usr/local/bin
ADD test /tmp/test
RUN bats /tmp/test

ENTRYPOINT ["/usr/local/bin/run-database.sh"]
