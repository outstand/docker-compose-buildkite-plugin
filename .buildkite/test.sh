#!/bin/bash

set -euo pipefail

echo "--- Running tests"

compose_params=(-f docker-compose.yml)
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE:-}" ]] ; then
  compose_params+=(-f "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE}")
else
  docker-compose "${compose_params[@]}" -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} build --pull myservice
fi

docker-compose "${compose_params[@]}" -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} up -d --scale myservice=0
docker-compose "${compose_params[@]}" -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} run \
  --name ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX}_myservice --rm \
  myservice /bin/sh -e -c 'echo hello world'
