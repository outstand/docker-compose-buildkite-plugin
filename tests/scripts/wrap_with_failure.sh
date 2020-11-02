#!/bin/bash

set -euo pipefail

echo "--- Starting Dependencies"
docker-compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME} \
  up -d --scale alpinewithfailinglink=0

echo "--- Saying hello"
docker-compose \
  -f tests/composefiles/docker-compose.v2.1.yml \
  -p buildkitefbb18885a61849569d2d93b765659b63 \
  --name buildkitefbb18885a61849569d2d93b765659b63_alpinewithfailinglink_build_11 \
  --rm \
  run \
  alpinewithfailinglink /bin/sh -e -c 'echo hello from alpine'
