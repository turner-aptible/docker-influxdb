#!/bin/bash

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

initialize_influxdb() {
  run-database.sh --initialize
}


wait_for_influxdb() {
  run-database.sh &
  
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

start_influxdb() {
  initialize_influxdb
  wait_for_influxdb
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