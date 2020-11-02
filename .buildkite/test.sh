#!/bin/bash

set -euo pipefail

echo "--- Running tests"

compose_params=(-f docker-compose.yml)
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE:-}" ]] ; then
  compose_params+=(-f "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE}")
else
  docker-compose "${compose_params[@]}" -p buildkite1111 build --pull myservice
fi

docker-compose "${compose_params[@]}" -p buildkite1111 up -d --scale myservice=0
docker-compose "${compose_params[@]}" -p buildkite1111 run \
  --name ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX}_myservice --rm \
  myservice /bin/sh -e -c 'echo hello world'
