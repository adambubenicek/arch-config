#!/usr/bin/env bash

function f() {
  if [[ " ${F_BOOTS[*]} " != *" $BOOT "* ]]; then
    return 0 
  fi

  owner="$1"
  group="$2"
  mode="$3"
  dest_path="$4"
  src_path="$(uuidgen)" 

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

  owner="$1"
  group="$2"
  mode="$3"
  dest_path="$4"
  
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
