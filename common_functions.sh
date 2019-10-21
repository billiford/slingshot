print_message() {
  echo ""
  echo "------------------------------------------"
  echo "$*"
  echo "------------------------------------------"
  echo ""
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

need() {
  which "$1" 1>/dev/null || apk add "$1" || die "$1"
}

start_server() {
  nohup dockerd > server_start.log  2>&1 &
  sleep 3
  cat server_start.log

  print_message "checking if process is running"
  docker info
  error_check $? "docker server online check"
  print_message "SERVER SUCCESSFULLY STARTED AND RUNNING"
}
