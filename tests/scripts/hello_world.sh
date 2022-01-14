#!/bin/bash

set -euo pipefail

echo "--- Starting Dependencies"
docker compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} \
  up -d --scale helloworldimage=0 \
  helloworldimage

echo "--- Saying hello"
docker compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} \
  run \
  --name ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX}_helloworldimage \
  --rm \
  helloworldimage /hello
