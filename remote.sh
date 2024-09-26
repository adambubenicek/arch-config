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

function ensure_attributes() {
  local path=$1
  local mode=$2
  local owner=$3
  local group=$4

  local existing
  read -r -a existing < <(stat -c '%a %U %G' "$1")

  local existing_mode="${existing[0]}"
  local existing_owner="${existing[1]}"
  local existing_group="${existing[2]}"

  if [[ "$mode" != "$existing_mode" ]]; then
    echo "Changing mode of '$path' from '$existing_mode' to '$mode'"
    # chmod "$mode" "$path"
  fi

  if [[ "$owner" != "$existing_owner" ]]; then
    echo "Changing owner of '$path' from '$existing_owner' to '$owner'"
    # chown "$path" "$owner"
  fi

  if [[ "$group" != "$existing_group" ]]; then
    echo "Changing group of '$path' from '$existing_group' to '$group'"
    # chgrp "$path" "$group"
  fi
}

function run_command() {
  local command="$*"
  echo "Running command '$command'"
  # $command
}
