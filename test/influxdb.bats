#!/usr/bin/env bats

setup() {
  # Muck up the port to make sure nothing assumes it's constant.
  export PORT="$("${BATS_TEST_DIRNAME}/pick-free-port")"

  # Create a temporary data directory
  export DATA_DIRECTORY="$(mktemp -d)"

  export USERNAME="foobar"
  export PASSPHRASE="$(pwgen -s 6)"
  export DATABASE="db$(pwgen -s 4)"
}

teardown() {
  if pidof influxd 2>/dev/null >&2; then
    pid="$(pidof influxd)"
    kill -TERM "$pid"
    wait_for_exit "$pid"
  fi

  rm -rf "$DATA_DIRECTORY"

  unset PORT
  unset DATA_DIRECTORY
  unset USERNAME
  unset PASSPHRASE
}

wait_for_influxdb() {
  local cmd=(
      influx -ssl -unsafeSsl -port "$PORT"
      -username "$USERNAME" -password "$PASSPHRASE"
      -execute "SHOW DATABASES"
  )

  for i in $(seq 0 4); do
    if "${cmd[@]}" 2>/dev/null; then
      return 0
    fi

    echo "[$i] InfluxDB is not responding to queries yet..." >&2
    sleep 1
  done

  # Give it one last chance, so we get log output when we fail.
  "${cmd[@]}"
}

wait_for_exit() {
  local pid="$1"
  local cmd=(kill -0 "$pid")

  for i in $(seq 0 4); do
    if ! "${cmd[@]}" 2>/dev/null; then
      return 0
    fi

    echo "[$i] InfluxDB has not exited yet..." >&2
    sleep 1
  done

  return 1
}

@test "It initializes and runs InfluxDB" {
  run-database.sh --initialize
  run-database.sh &

  wait_for_influxdb
}

@test "It writes data" {
  run-database.sh --initialize
  run-database.sh &
  wait_for_influxdb

  utcNow="$(TZ=UTC date "+%s")"

  curl -k -fsSL "https://localhost:${PORT}/write?db=${DATABASE}" \
    -u "${USERNAME}:${PASSPHRASE}" \
    --data-binary "series,foo=bar value=123 ${utcNow}"
}
