export SSH_HOST="${1:-localhost}"
export SSH_USER="adam"

source <(sudo cat .env)
source local.sh

echo "$REMOTE_HOSTNAME"
d root root 755 /usr/lib64/firefox/
f root root 644 /usr/lib64/firefox/firefox.cfg
d root root 755 /usr/lib64/firefox/defaults/
d root root 755 /usr/lib64/firefox/defaults/pref
f root root 644 /usr/lib64/firefox/defaults/pref/autoconfig.js

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys

run
