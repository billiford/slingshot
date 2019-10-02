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
