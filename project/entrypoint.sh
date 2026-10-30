#!/bin/bash
set -euo pipefail

mkdir -p /run/sshd
bash /create_users.sh
exec /usr/sbin/sshd -D -e
