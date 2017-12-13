#!/bin/bash
set -o errexit
set -o nounset

. ./test-helpers.sh

IMG="$1"
CURL_IMG="tutum/curl"

INFLUXDB_CONTAINER="influxdb-test"
DATA_CONTAINER="${INFLUXDB_CONTAINER}-test"
NET_NAME="${INFLUXDB_CONTAINER}-net"

NET_IP=172.18.0.21

cleanup () {
  echo "Cleaning up"
  docker rm -f "$INFLUXDB_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NET_NAME" || true
}

curl_influxdb() {
  path="$1"
  shift

  docker run --rm \
    --net "$NET_NAME" \
    "$CURL_IMG" curl \
    -kfsSL -u "myUser:myPass" \
    "https://${NET_IP}:12345/${path}" "$@"
}

wait_for_influxdb() {
  for _ in $(seq 1 100); do
    if curl_influxdb "ping" -G; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

trap cleanup EXIT
quietly cleanup

echo "Downloading ${CURL_IMG}"
docker pull "$CURL_IMG" >/dev/null 2>&1

echo "Creating network"
docker network create --subnet=172.18.0.0/16 "$NET_NAME"

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Initializing data container"
quietly docker run -it --rm \
  -e USERNAME=myUser -e PASSPHRASE=myPass -e DATABASE=myDb \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_12345=12345 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize

echo "Starting container"
quietly docker run -d "--name=${INFLUXDB_CONTAINER}" \
  -e PORT=12345 -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_12345=12345 \
  --volumes-from "$DATA_CONTAINER" \
  --net "$NET_NAME" --ip "$NET_IP" \
  "$IMG"

wait_for_influxdb

echo "Restarting container (clean)"
utc0="$(TZ=UTC date "+%s")"
curl_influxdb "write?db=myDb" --data-binary "series,foo=bar value=123 ${utc0}"
docker restart "$INFLUXDB_CONTAINER"
wait_for_influxdb

echo "Verifying data"
curl_influxdb "query?db=myDb" -G \
  --data-urlencode 'q=SELECT "value" FROM "series"' | grep "123"


echo "Restarting container (dirty)"
utc1="$(TZ=UTC date "+%s")"
curl_influxdb "write?db=myDb" --data-binary "series,foo=bar value=456 ${utc1}"
docker kill -s KILL "$INFLUXDB_CONTAINER"
docker restart "$INFLUXDB_CONTAINER"
wait_for_influxdb

echo "Verifying data"
curl_influxdb "query?db=myDb" -G \
  --data-urlencode 'q=SELECT "value" FROM "series"' | grep "456"
