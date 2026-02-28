#!/bin/sh
# Deploy systemd unit and timer files from the repo to /etc/systemd/system
# Usage: sudo ./install-systemd-units.sh [--enable ufw-metrics.timer,fail2ban-metrics.timer]
set -eu

REPO_DIR="${REPO_DIR:-$(pwd)}"
ENABLE_LIST="${1:-ufw-metrics.timer,fail2ban-metrics.timer}"

# Ensure we have files
if [ ! -d "$REPO_DIR" ]; then
  echo "Repo unit dir not found: $REPO_DIR"
  exit 1
fi

echo "Installing units from: $REPO_DIR"

# Copy .service and .timer files
for f in "$REPO_DIR"/*.{service,timer}; do
  [ -e "$f" ] || continue
  echo "Installing $f -> /etc/systemd/system/$(basename "$f")"
  install -o root -g root -m 644 "$f" "/etc/systemd/system/$(basename "$f")"
done

# Reload systemd and enable/start requested timers
systemctl daemon-reload

IFS=','; for t in $ENABLE_LIST; do
  t=$(echo "$t" | tr -d ' ')
  if [ -n "$t" ]; then
    echo "Enabling and starting $t"
    systemctl enable --now "$t"
  fi
done

echo "Done. Check status with: systemctl status <unit.name>"
