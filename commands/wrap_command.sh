#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"

expand_headers_on_error() {
  echo "^^^ +++"
}
trap expand_headers_on_error ERR

test -f "$override_file" && rm "$override_file"

run_params=()
pull_params=()
pull_services=()
prebuilt_candidates=()

# Build a list of services that need to be pulled down
while read -r name ; do
  if [[ -n "$name" ]] ; then
    pull_services+=("$name")

    if ! in_array "$name" "${prebuilt_candidates[@]}" ; then
      prebuilt_candidates+=("$name")
    fi
  fi
done <<< "$(plugin_read_list PULL)"

# A list of tuples of [service image cache_from] for build_image_override_file
prebuilt_service_overrides=()
prebuilt_services=()

# We look for a prebuilt images for all the pull services and the run_service.
for service_name in "${prebuilt_candidates[@]}" ; do
  if prebuilt_image=$(get_prebuilt_image "$service_name") ; then
    echo "~~~ :docker: Found a pre-built image for $service_name"
    prebuilt_service_overrides+=("$service_name" "$prebuilt_image" "")
    prebuilt_services+=("$service_name")

    # If it's prebuilt, we need to pull it down
    if [[ -z "${pull_services:-}" ]] || ! in_array "$service_name" "${pull_services[@]}" ; then
      pull_services+=("$service_name")
   fi
  fi
done

# If there are any prebuilts, we need to generate an override docker-compose file
if [[ ${#prebuilt_services[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating docker-compose override file for prebuilt services"
  build_image_override_file "${prebuilt_service_overrides[@]}" | tee "$override_file"
  pull_params+=(-f "$override_file")
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE=$override_file
fi

# If there are multiple services to pull, run it in parallel (although this is now the default)
if [[ ${#pull_services[@]} -gt 1 ]] ; then
  pull_params+=("pull" "--parallel" "${pull_services[@]}")
elif [[ ${#pull_services[@]} -eq 1 ]] ; then
  pull_params+=("pull" "${pull_services[0]}")
fi

# Pull down specified services
if [[ ${#pull_services[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Pulling services ${pull_services[0]}"
  retry "$pull_retries" run_docker_compose "${pull_params[@]}"

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo
fi

build_params=(--pull)

if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
  build_params+=(--no-cache)
fi

while read -r arg ; do
  [[ -n "${arg:-}" ]] && build_params+=("--build-arg" "${arg}")
done <<< "$(plugin_read_list ARGS)"

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_REQUIRE_PREBUILD:-}" =~ ^(true|on|1)$ ]] && [[ ! -f "$override_file" ]] ; then
  echo "+++ 🚨 No pre-built image found from a previous 'build' step for this service and config file."
  echo "The step specified that it was required"
  exit 1

fi

# Assemble the shell and command arguments into the docker arguments

display_command=()

if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  IFS=" " read -r -a command <<< "$BUILDKITE_COMMAND"
  run_params+=$command
  display_command+=("${BUILDKITE_COMMAND}")
fi

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

(
  echo "+++ :docker: Running ${display_command[*]:-}" >&2

  if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE:-}" ]] ; then
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE=$BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE
  fi

  BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME="$(docker_compose_project_name)"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROJECT_NAME

  BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX="$(docker_compose_project_name)_build_${BUILDKITE_BUILD_NUMBER}"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONTAINER_PREFIX

  plugin_prompt_and_run "${run_params[@]}"
)

exitcode=$?

# Restore -e as an option.
set -e

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode, run params:"
  echo "${run_params[@]}"
fi

if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
  if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" != "false" ]] ; then

    # Get list of failed containers
    containers=()
    while read -r container ; do
      [[ -n "$container" ]] && containers+=("$container")
    done <<< "$(docker_ps_by_project -q)"

    failed_containers=()
    if [[ 0 != "${#containers[@]}" ]] ; then
      while read -r container ; do
        [[ -n "$container" ]] && failed_containers+=("$container")
      done <<< "$(docker inspect -f '{{if ne 0 .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{ end }}' \
        "${containers[@]}")"
    fi

    if [[ 0 != "${#failed_containers[@]}" ]] ; then
      echo "+++ :warning: Some containers had non-zero exit codes"
      docker_ps_by_project \
        --format 'table {{.Label "com.docker.compose.service"}}\t{{ .ID }}\t{{ .Status }}'
    fi

    check_linked_containers_and_save_logs \
      "dont-skip-anything" "docker-compose-logs" \
      "$(plugin_read_config UPLOAD_CONTAINER_LOGS "on-error")"

    if [[ -d "docker-compose-logs" ]] && test -n "$(find docker-compose-logs/ -maxdepth 1 -name '*.log' -print)"; then
      echo "~~~ Uploading linked container logs"
      buildkite-agent artifact upload "docker-compose-logs/*.log"
    fi
  fi
fi

return $exitcode
