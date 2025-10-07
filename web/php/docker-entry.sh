#!/bin/sh
set -e

# Ensure PHP worker user can access the Docker socket by matching its group
if [ -S /var/run/docker.sock ]; then
  # Try GNU (stat -c) then BSD (stat -f) style
  GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null || true)
  if [ -n "$GID" ]; then
    # Create a group with this GID if it doesn't exist
    if ! getent group | awk -F: '{print $3}' | grep -qx "$GID"; then
      addgroup -g "$GID" dockergid || true
    fi
    # Find the group name for this GID
    GROUP_NAME=$(getent group | awk -F: -v gid="$GID" '$3==gid {print $1; exit}')
    if [ -n "$GROUP_NAME" ]; then
      usermod -a -G "$GROUP_NAME" www-data 2>/dev/null || addgroup www-data "$GROUP_NAME" 2>/dev/null || true
    fi
  fi
fi

exec php-fpm
