#!/usr/bin/env bash
set -ue
cd "$(dirname "$0")" || exit

# shellcheck source=/dev/null
source .env
source colors.sh

function f() {
  if [[ " ${f_boots[*]} " != *" $boot "* ]]; then
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

    eval "$script" > "$sync_dir/$src_path"
  else
    cat ".$dest_path" > "$sync_dir/$src_path"
  fi
  
  if [[ "$boot" == "install-chroot" ]]; then
    dest_path="/mnt$dest_path"
  fi

  {
    echo ensure_file "$dest_path" "./$src_path"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$sync_dir/remote.sh"
}

function d() {
  if [[ " ${d_boots[*]} " != *" $boot "* ]]; then
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
  
  if [[ "$boot" == "install-chroot" ]]; then
    dest_path="/mnt$dest_path"
  fi

  {
    echo ensure_dir "$dest_path" "$mode"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$sync_dir/remote.sh"
}

function c() {
  if [[ " ${c_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  cmd="$*" 

  if [[ "$boot" == "install-chroot" ]]; then
    cmd="arch-chroot /mnt $cmd"
  fi

  echo "run_command $cmd" >> "$sync_dir/remote.sh"
}

boot=regular
OPTIND=1
while getopts "b:" opt; do
  case "$opt" in
    b) boot=$OPTARG;;
    *) break;;
  esac
done
shift $((OPTIND-1))

ssh_host="${1:-localhost}"

printf -v divider '%80s' '' 
divider="\e[2m${divider// /=}\e[0m"

sync_dir="$(mktemp -d)"

cp remote.sh "$sync_dir/remote.sh"

ssh_opts=(
 -o ControlMaster=auto
 -o ControlPath=/root/.ssh/%C
 -o ControlPersist=60
)

HOSTNAME=$(ssh "${ssh_opts[@]}" "$ssh_host" uname -n)

echo -e "$divider"
echo -en "> Syncing to '\e[1;37m$HOSTNAME\e[0m' "
echo -e "during its '\e[1;37m$boot\e[0m' boot."

source ./config.sh

if [[ $boot != "regular" ]]; then
  ssh_opts+=(
    -o StrictHostKeyChecking=off
    -o UserKnownHostsFile=/dev/null 
  )
fi

remote_sync_dir=$(ssh "${ssh_opts[@]}" "$ssh_host" mktemp -d)

scp "${ssh_opts[@]}" -q "$sync_dir"/* "$ssh_host:$remote_sync_dir" 
ssh "${ssh_opts[@]}" "$ssh_host" "$remote_sync_dir"/remote.sh || true
ssh "${ssh_opts[@]}" "$ssh_host" rm -rf "$remote_sync_dir"

rm -rf "$sync_dir"
