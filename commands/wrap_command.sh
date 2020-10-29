#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

# run_service="$(plugin_read_config RUN)"
# container_name="$(docker_compose_project_name)_${run_service}_build_${BUILDKITE_BUILD_NUMBER}"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"

expand_headers_on_error() {
  echo "^^^ +++"
}
trap expand_headers_on_error ERR

test -f "$override_file" && rm "$override_file"

run_params=()
pull_params=()
up_params=()
pull_services=()
prebuilt_candidates=("$run_service")

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
  run_params+=(-f "$override_file")
  pull_params+=(-f "$override_file")
  up_params+=(-f "$override_file")
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

# # append env vars provided in ENV or ENVIRONMENT, these are newline delimited
# while IFS=$'\n' read -r env ; do
#   [[ -n "${env:-}" ]] && run_params+=("-e" "${env}")
# done <<< "$(printf '%s\n%s' \
#   "$(plugin_read_list ENV)" \
#   "$(plugin_read_list ENVIRONMENT)")"

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_REQUIRE_PREBUILD:-}" =~ ^(true|on|1)$ ]] && [[ ! -f "$override_file" ]] ; then
  echo "+++ 🚨 No pre-built image found from a previous 'build' step for this service and config file."
  echo "The step specified that it was required"
  exit 1

elif [[ ! -f "$override_file" ]]; then
  echo "~~~ :docker: Building Docker Compose Service: $run_service" >&2
  echo "⚠️ No pre-built image found from a previous 'build' step for this service and config file. Building image..."

  # Ideally we'd do a pull with a retry first here, but we need the conditional pull behaviour here
  # for when an image and a build is defined in the docker-compose.ymk file, otherwise we try and
  # pull an image that doesn't exist
  run_docker_compose build "${build_params[@]}" "$run_service"

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo
fi

# Assemble the shell and command arguments into the docker arguments

display_command=()

if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  run_params+=("${BUILDKITE_COMMAND}")
  display_command+=("'${BUILDKITE_COMMAND}'")
fi

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

(
  echo "+++ :docker: Running ${display_command[*]:-}" >&2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_OVERRIDE_FILE=$override_file
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
      "$run_service" "docker-compose-logs" \
      "$(plugin_read_config UPLOAD_CONTAINER_LOGS "on-error")"

    if [[ -d "docker-compose-logs" ]] && test -n "$(find docker-compose-logs/ -maxdepth 1 -name '*.log' -print)"; then
      echo "~~~ Uploading linked container logs"
      buildkite-agent artifact upload "docker-compose-logs/*.log"
    fi
  fi
fi

return $exitcode
