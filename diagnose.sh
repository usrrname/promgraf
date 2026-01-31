# Full diagnostic
echo "=== Container Info ==="
docker inspect prometheus --format 'Started: {{.State.StartedAt}} | Status: {{.State.Status}}'

echo -e "\n=== Retention ==="
curl -s http://house.local:9090/api/v1/status/runtimeinfo | jq '.data | {retentionTime: .storageRetention, retentionSize: .storageRetentionSize}'

echo -e "\n=== TSDB Contents ==="
docker exec prometheus ls -lh /prometheus/ 2>/dev/null | head -15

echo -e "\n=== Blocks ==="
docker exec prometheus find /prometheus -maxdepth 1 -type d -name "*-*-*" 2>/dev/null | wc -l
echo "compacted blocks found"

# Check the actual time range of stored data
docker exec prometheus ls -lht /prometheus/ | grep "^d" | grep -v "wal\|chunks"

# Check size of each block
for block in $(docker exec prometheus ls -1 /prometheus/ | grep "^01"); do
  echo "Block $block:"
  docker exec prometheus du -sh /prometheus/$block 2>/dev/null
done