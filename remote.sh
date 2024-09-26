function ensure_content() {
  if ! cmp -s "$1" "$2"; then
    echo "Updating file '$1'"
    diff --color=always "$1" "$2"
    # cat "$2" > "$1"
  fi
}

function ensure_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Creating directory '$1'"
    # mkdir --mode="$2" "$1"
  fi
}

function ensure_mode() {
  local mode
  mode="$(stat -c '%a' "$1")"

  if [[ "$mode" != "$2" ]]; then
    echo "Changing mode of '$1' from '$mode' to '$2'"
    # chmod "$2" "$1"
  fi
}

function ensure_owner() {
  local owner
  owner="$(stat -c '%U' "$1")"

  if [[ "$owner" != "$2" ]]; then
    echo "Changing owner of '$1' from '$owner' to '$2'"
    # chown "$2" "$1"
  fi
}

function ensure_group() {
  local group
  group="$(stat -c '%G' "$1")"

  if [[ "$group" != "$2" ]]; then
    echo "Changing group of '$1' from '$group' to '$2'"
    # chgrp "$2" "$1"
  fi
}
