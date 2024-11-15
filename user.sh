ssh_host="${1:-localhost}"
ssh_user="adam"

source <(sudo cat .env)
source local.sh

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys

run adam 10.98.217.121
