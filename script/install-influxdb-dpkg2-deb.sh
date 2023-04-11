#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o xtrace

FILE="influxdb2-${INFLUXDB_VERSION}-amd64.deb"
URL="https://dl.influxdata.com/influxdb/releases/${FILE}"

wget "${URL}"

echo "${INFLUXDB_DEB_SHA256} ${FILE}" | sha256sum -c

dpkg -i "${FILE}"