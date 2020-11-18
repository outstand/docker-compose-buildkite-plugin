#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

@test "Config export: Does not export on build" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice

  run $PWD/hooks/pre-command

  assert_success
  refute_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES="
  refute_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME="
  refute_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX="
}

@test "Config export: Exports on run" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES=docker-compose.yml"
  assert_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME=buildkite1111"
  assert_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX=buildkite1111_build_1"
  unstub buildkite-agent
}

@test "Config export: Exports on wrap_command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WRAP_COMMAND=1

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES=docker-compose.yml"
  assert_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME=buildkite1111"
  assert_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX=buildkite1111_build_1"
}

@test "Config export: Exports override file" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES=docker-compose.yml docker-compose.buildkite-1-override.yml"
  assert_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME=buildkite1111"
  assert_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX=buildkite1111_build_1"
  unstub buildkite-agent
}

@test "Config export: Exports override file with pull and wrap_command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WRAP_COMMAND=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_0=myservice

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES=docker-compose.yml docker-compose.buildkite-1-override.yml"
  assert_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME=buildkite1111"
  assert_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX=buildkite1111_build_1"
  unstub buildkite-agent
}

@test "Config export: Exports custom config files" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1=tests/composefiles/docker-compose.v2.1.yml

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "Setting DOCKER_COMPOSE_CONFIG_FILES=tests/composefiles/docker-compose.v2.0.yml tests/composefiles/docker-compose.v2.1.yml"
  assert_output --partial "Setting DOCKER_COMPOSE_PROJECT_NAME=buildkite1111"
  assert_output --partial "Setting DOCKER_COMPOSE_CONTAINER_PREFIX=buildkite1111_build_1"
}
