# Troubleshooting 

## node_exporter Textfile Collector with Docker

**Problem**: Bind mount not visible inside container.

**Cause**: Container was created before the host directory existed.

**Fix**: Recreate the container:
```bash
docker compose up -d --no-deps --force-recreate node-exporter
```

**Mount example** (docker-compose.yml):
```yaml
volumes:
  - /mnt/storage/node_exporter/textfile_collector:/var/lib/node_exporter/textfile_collector:ro
```

## Metric Type Error

**Problem**: Metrics not appearing in Prometheus.

**Cause**: Invalid metric type in `.prom` file (`# TYPE ufw_blocked_recent graph`).

**Fix**: Use valid types (`gauge`, `counter`, `histogram`, `summary`):
```bash
sed -i 's/^# TYPE ufw_blocked_recent .*/# TYPE ufw_blocked_recent gauge/' /var/lib/node_exporter/textfile_collector/ufw.prom
```

Update scripts to always write valid types.

## rsyslog + UFW Logs

**Problem**: No `/var/log/ufw.log` file.

**Cause**: UFW logs go to journald by default; rsyslog not installed or no rule.

**Fix**: Install rsyslog and add config:
```bash
# /etc/rsyslog.d/20-ufw.conf
:msg, contains, "UFW" -/var/log/ufw.log
& stop
```

Then:
```bash
sudo apt install -y rsyslog
sudo systemctl enable --now rsyslog
```

## Logrotate Errors

**Problem**: `failed to rename ... Device or resource busy`.

**Cause**: File held open by rsyslog; bind mount prevents rename.

**Fix**: Use `copytruncate` in logrotate config:
```
/var/log/ufw.log {
    daily
    rotate 14
    compress
    copytruncate
    ...
}
```

**Problem**: `unknown option 'root'` warning.

**Cause**: Malformed `create` directive in `/etc/logrotate.conf`.

**Fix**: Ensure proper format:
```
create 0640 root adm
```
(no leading spaces, starts with `create`)

## Storage Distribution

**Principle**: Keep microSD writes minimal; use `/mnt/storage` for write-heavy workloads.

**Options**:
- Persistent journal: bind-mount `/mnt/storage/journal` → `/var/log/journal`
- Docker data-root: set `"data-root": "/mnt/storage/docker"` in `/etc/docker/daemon.json`
- Logs: bind-mount or write directly to `/mnt/storage/logs/`

## Key Commands

```bash
# Recreate container to apply bind mount
docker compose up -d --no-deps --force-recreate node-exporter

# Test logrotate
sudo logrotate --debug /etc/logrotate.d/ufw

# Force logrotate
sudo logrotate -f /etc/logrotate.d/ufw

# Check journal for UFW
sudo journalctl -k | grep -i UFW

# Check systemd timer
sudo systemctl status ufw-metrics.timer

# View textfile metrics from node-exporter
curl -s http://localhost:9100/metrics | grep -E 'ufw_|fail2ban_'
```

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/monitoring/ufw-metrics.sh` | Writes UFW metrics to textfile collector |
| `scripts/monitoring/fail2ban-metrics.sh` | Writes Fail2ban metrics to textfile collector |
| `etc/systemd/ufw-metrics.{service,timer}` | Runs ufw-metrics.sh periodically |
| `etc/systemd/fail2ban-metrics.{service,timer}` | Runs fail2ban-metrics.sh periodically |
| `etc/rsyslog.d/20-ufw.conf` | Routes UFW messages to /var/log/ufw.log |
| `etc/logrotate.d/ufw` | Rotates UFW log files |
| `rules/security_rules.yml` | Prometheus alerting rules for UFW/Fail2ban |
