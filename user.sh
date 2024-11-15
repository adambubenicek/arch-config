export SSH_HOST="${1:-localhost}"
export SSH_USER="adam"

source <(sudo cat .env)
source local.sh

echo "$REMOTE_HOSTNAME"

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys

run
