#!/usr/bin/env bash

function f() {
  if [[ " ${F_BOOTS[*]} " != *" $BOOT "* ]]; then
    return 0 
  fi

  local src_path
  local dest_path
  local template
  local mode
  local owner
  local group

  src_path="$(uuidgen)" 
  dest_path="$1"
  shift

  OPTIND=1
  while getopts "tm:o:g:" opt; do
    case "$opt" in
      t) template=true;;
      m) mode=$OPTARG;;
      o) owner=$OPTARG;;
      g) group=$OPTARG;;
      *) break;;
    esac
  done

  template=${template:-false}
  mode=${mode:-644}
  owner=${owner:-root}
  group=${group:-$owner}

  if [[ "$template" == true ]]; then
    local script=""

    while IFS= read -r line; do
      if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
        script+="${BASH_REMATCH[1]}"$'\n'
      elif [[ "$line" =~ [^[:space:]]*%=[[:space:]]*(.*)$ ]]; then
        script+="echo \"${BASH_REMATCH[1]}\""$'\n'
      else
        script+="echo '${line//\'/\'\"\'\"\'}'"$'\n'
      fi
    done < ".$dest_path"

    eval "$script" > "$SYNC_DIR/$src_path"
  else
    cat ".$dest_path" > "$SYNC_DIR/$src_path"
  fi
  
  if [[ "$BOOT" == "install-chroot" ]]; then
    dest_path="/mnt$dest_path"
  fi

  {
    echo ensure_file "$dest_path" "./$src_path"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$SYNC_DIR/remote.sh"
}

function d() {
  if [[ " ${D_BOOTS[*]} " != *" $BOOT "* ]]; then
    return 0 
  fi

  local dest_path
  local mode
  local owner
  local group

  dest_path="$1"
  shift

  OPTIND=1
  while getopts "m:o:g:" opt; do
    case "$opt" in
      m) mode=$OPTARG;;
      o) owner=$OPTARG;;
      g) group=$OPTARG;;
      *) break;;
    esac
  done

  mode=${mode:-755}
  owner=${owner:-root}
  group=${group:-$owner}
  
  if [[ "$BOOT" == "install-chroot" ]]; then
    dest_path="/mnt$dest_path"
  fi

  {
    echo ensure_dir "$dest_path" "$mode"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$SYNC_DIR/remote.sh"
}

function c() {
  if [[ " ${C_BOOTS[*]} " != *" $BOOT "* ]]; then
    return 0 
  fi

  cmd="$*" 

  if [[ "$BOOT" == "install-chroot" ]]; then
    cmd="arch-chroot /mnt $cmd"
  fi

  echo "run_command $cmd" >> "$SYNC_DIR/remote.sh"
}
