cleanup() {
  echo "killing docker server"
  curl -s $KILL_HOST/kill
}

print_message() {
  echo ""
  echo "------------------------------------------"
  echo "$*"
  echo "------------------------------------------"
  echo ""
}

check_docker_server_health() {
  EXIT_CODE=1
  i=0
  while [ "${EXIT_CODE}" -ne 0 ]
  do
    sleep 2
    echo "Attempt $i to connect to docker daemon"
    nc localhost 2375 -v
    EXIT_CODE=$?
    i=$((i + 1))
  done
}

die() {
  print_message "$*" 1>&2
  exit 1
}

need_var() {
  test -n "$1" || die "$2 does not exist, exiting script"
}

error_check() {
  test "$1" -ne 0 && die "$2 did not return a success code, exiting script"
}
