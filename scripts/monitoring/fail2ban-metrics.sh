#!/bin/sh
# Writes fail2ban metrics to node_exporter textfile collector directory
OUT=/var/lib/node_exporter/textfile_collector/fail2ban.prom
TMP=$(mktemp)

if ! command -v fail2ban-client >/dev/null 2>&1; then
  echo "# HELP fail2ban_client_missing Fail2ban client missing on host" > "$OUT"
  echo "# TYPE fail2ban_client_missing gauge" >> "$OUT"
  echo "fail2ban_client_missing 1" >> "$OUT"
  chmod 644 "$OUT"
  exit 0
fi

echo "# HELP fail2ban_banned_total Number of currently banned IPs per jail" > "$TMP"
echo "# TYPE fail2ban_banned_total gauge" >> "$TMP"

JAILS=$(fail2ban-client status 2>/dev/null | sed -n '2p' | cut -d: -f2 | tr ',' ' ' || true)
if [ -z "$JAILS" ]; then
  JAILS=$(fail2ban-client status 2>/dev/null | awk -F: '/Jail/{print $2}' | tr ',' ' ' | tr -d ' ')
fi

for j in $JAILS; do
  j=$(echo "$j" | tr -d ' ')
  [ -z "$j" ] && continue
  BANNED=0
  LIST=$(fail2ban-client status "$j" 2>/dev/null | awk -F: '/Banned IP list/ {print $2}')
  if [ -n "$LIST" ]; then
    BANNED=$(echo "$LIST" | wc -w)
  else
    LIST2=$(fail2ban-client get "$j" banned 2>/dev/null || true)
    if [ -n "$LIST2" ]; then
      BANNED=$(echo "$LIST2" | wc -w)
    else
      JAIL_LOG=$(fail2ban-client status "$j" 2>/dev/null | awk -F: '/Log file/ {print $2}' | tr -d ' ')
      if [ -n "$JAIL_LOG" ] && [ -f "$JAIL_LOG" ]; then
        BANNED=$(grep -c -E 'Ban' "$JAIL_LOG" 2>/dev/null || true)
      fi
    fi
  fi
  echo "fail2ban_banned_total{jail=\"${j}\"} ${BANNED:-0}" >> "$TMP"
done

mv "$TMP" "$OUT"
chmod 644 "$OUT"
