#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

@test "Read docker-compose config when none exists" {
  run docker_compose_config_files

  assert_success
  assert_output "docker-compose.yml"
}

@test "Read docker-compose config when there are several" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0="llamas1.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1="llamas2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_2="llamas3.yml"
  run docker_compose_config_files

  assert_success
  assert_equal "${lines[0]}" "llamas1.yml"
  assert_equal "${lines[1]}" "llamas2.yml"
  assert_equal "${lines[2]}" "llamas3.yml"
}

@test "Read colon delimited config files" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="llamas1.yml:llamas2.yml"
  run docker_compose_config_files

  assert_success
  assert_equal "${lines[0]}" "llamas1.yml"
  assert_equal "${lines[1]}" "llamas2.yml"
}
