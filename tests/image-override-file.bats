#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

myservice_override_file1=$(cat <<-EOF
services:
  myservice:
    image: newimage:1.0.0
EOF
)

myservice_override_file2=$(cat <<-EOF
services:
  myservice1:
    image: newimage1:1.0.0
  myservice2:
    image: newimage2:1.0.0
EOF
)

myservice_override_file3=$(cat <<-EOF
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_from:
        - my.repository/myservice:latest
EOF
)

@test "Build a docker-compose override file" {
  run build_image_override_file "myservice" "newimage:1.0.0" ""

  assert_success
  assert_output "$myservice_override_file1"
}

@test "Build a docker-compose override file with multiple entries" {
  run build_image_override_file \
    "myservice1" "newimage1:1.0.0" "" \
    "myservice2" "newimage2:1.0.0" ""

  assert_success
  assert_output "$myservice_override_file2"
}

@test "Build a docker-compose file with cache-from" {
  run build_image_override_file "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_success
  assert_output "$myservice_override_file3"
}
