#!/bin/bash

set -euo pipefail

echo "--- Starting Dependencies"
docker compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} \
  up -d --scale alpinewithfailinglink=0 \
  alpinewithfailinglink 

echo "--- Saying hello"
docker compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} \
  run \
  --name ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX}_alpinewithfailinglink \
  --rm \
  alpinewithfailinglink /bin/sh -e -c 'echo hello from alpine'
