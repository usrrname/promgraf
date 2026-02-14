#!/bin/sh
# Writes UFW metrics to node_exporter textfile collector directory
OUT=/var/lib/node_exporter/textfile_collector/ufw.prom
TMP=$(mktemp)
TOPN=20
LOG1=/var/log/ufw.log
LOG2=/var/log/syslog
COUNT=0

if [ -f "$LOG1" ]; then
  COUNT=$(grep -c -E 'UFW (BLOCK|DENY)|BLOCK' "$LOG1" 2>/dev/null || true)
  TOPN=$(grep -c -E 'UFW (BLOCK|DENY)|BLOCK' "$LOG1" 2>/dev/null | sort -nr | head -n "$TOPN" | awk '{print $2}')
  TOPN_COUNT=0
  # Initialize arrays for top IPs and their counts
  TOPN_IPS=()
  for ip in $TOPN; do
    # Sum up the total number of blocked events for each IP and protocol
    COUNT=$(grep -c -E "BLOCK $ip (TCP|UDP|ICMP)" "$LOG1" 2>/dev/null || true)
    TOPN_IPS+=("${ip} ${COUNT}")
  done

# otherwise if log2 exists
elif [ -f "$LOG2" ]; then

  COUNT=$(grep -c -E 'UFW (BLOCK|DENY)|UFW:' "$LOG2" 2>/dev/null || true)
else
  if command -v journalctl >/dev/null 2>&1; then
    COUNT=$(journalctl -k -u ufw --no-pager 2>/dev/null | grep -c -E 'UFW (BLOCK|DENY)|UFW:' || true)
    if [ "$COUNT" -eq 0 ]; then
      COUNT=$(journalctl -k --no-pager 2>/dev/null | grep -c -E 'UFW (BLOCK|DENY)|UFW:' || true)
    fi
  fi
fi

RECENT=0
if command -v journalctl >/dev/null 2>&1; then
  RECENT=$(journalctl --since "5 minutes ago" -k --no-pager 2>/dev/null | grep -c -E 'UFW (BLOCK|DENY)|UFW:' || true)
else
  if [ -f "$LOG1" ]; then
    RECENT=$(tail -n 2000 "$LOG1" 2>/dev/null | grep -c -E 'UFW (BLOCK|DENY)|BLOCK' || true)
  elif [ -f "$LOG2" ]; then
    RECENT=$(tail -n 2000 "$LOG2" 2>/dev/null | grep -c -E 'UFW (BLOCK|DENY)|UFW:' || true)
  fi
fi

cat > "$TMP" <<EOF
# HELP ufw_blocked_total Total number of UFW blocked events (accumulated from log files)
# TYPE ufw_blocked_total counter
ufw_blocked_total ${COUNT:-0}
# HELP ufw_blocked_recent Number of UFW blocked events in the last 5 minutes (approx)
# TYPE ufw_blocked_recent gauge
ufw_blocked_recent ${RECENT:-0}
# HELP ufw_blocked_top_ips Top 10 IPs blocked by UFW
# TYPE ufw_blocked_top_ips counter
${TOPN:-}
# HELP ufw_blocked_top_ips_count Number of blocked events for each IP
# TYPE ufw_blocked_top_ips_count counter
${TOPN_COUNT:-}
EOF

mv "$TMP" "$OUT"
chmod 644 "$OUT"
