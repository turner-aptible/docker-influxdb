#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

echo "Unit Tests..."
docker run -it --rm --entrypoint "bash" "$IMG" \
  -c "apt-install --no-install-recommends --no-install-suggests python-minimal curl psmisc >/dev/null && bats /tmp/test"

echo
echo "Restart Test..."
./test-restart.sh "$IMG"

echo "#############"
echo "# Tests OK! #"
echo "#############"
