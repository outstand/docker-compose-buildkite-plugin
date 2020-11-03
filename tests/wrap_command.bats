#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'
load '../lib/wrap_command'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

@test "Wrap command without a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WRAP_COMMAND=1
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=".buildkite/test.sh"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_build_1_myservice --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "Running tests"
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
}

@test "Wrap command with spaces" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WRAP_COMMAND=1
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=".buildkite/test.sh foo"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_build_1_myservice --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "Running tests"
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
}

@test "Wrap command with a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WRAP_COMMAND=1
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=".buildkite/test.sh"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_0=myservice

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -f docker-compose.buildkite-1-override.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -f docker-compose.buildkite-1-override.yml -p buildkite1111 run --name buildkite1111_build_1_myservice --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "Running tests"
  assert_output --partial "pulled myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}
