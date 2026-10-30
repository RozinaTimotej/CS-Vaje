#!/bin/bash
# Create the lab accounts. Safe to run more than once: existing users keep
# their home directory and get the lab password again.

set -euo pipefail

ensure_user() {
  local name="$1"
  local pass="$2"

  if id "$name" >/dev/null 2>&1; then
    echo "User ${name} already exists, resetting password"
    usermod -s /bin/bash "$name"
  else
    useradd -m -s /bin/bash "$name"
    echo "Created ${name}"
  fi

  echo "${name}:${pass}" | chpasswd
}

echo "Creating users for SSH lab..."

ensure_user student "password123"
ensure_user weakuser "123456"
ensure_user mediumuser "Password123"
ensure_user stronguser "Str0ng!Pass#2026"

echo "Users created:"
echo " - student / password123"
echo " - weakuser / 123456"
echo " - mediumuser / Password123"
echo " - stronguser / Str0ng!Pass#2026"
echo "Done."
