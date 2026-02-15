# Prometheus + Alertmanager + Grafana with Docker Compose

HomeNAS monitoring for my Pi 4 NAS using:
- Prometheus `localhost:9090` w/remote write to Grafana Cloud 
- Grafana `localhost:3000`
- Docker Compose
- Alertmanager with email notifications `localhost:9093`

Listening for 
- Node Exporter metrics on port `9100`
  - UFW metrics w/custom systemd service and timer
  - Fail2ban metrics w/custom systemd service and timer
- cAdvisor on port `8080`
- immich API on port `8081` 
- immich microservices `8082`

## Run

```bash
docker compose up -d
```

### Directory Structure
```bash
.
├── alertmanager       # routing and notification settings
├── docker-compose.yml
├── grafana
|   └── provisioning/
|       ├── dashboards/
|       └── datasources/
├── prometheus.yml
├── README.md
└── rules              # custom alerting and recording rules
```

Update the node exporter container with the latest config and mounts:
`docker compose up -d --no-deps --force-recreate node-exporter`

Link the UFW metrics systemd service and timer, reload the daemon, enable and start the timer, and check their status:

```
sudo systemctl link ~/code/prometheus/fail2ban-metrics.service
sudo systemctl link ~/code/prometheus/fail2ban-metrics.timer
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-metrics.timer
sudo systemctl status <timer> <service> --no-pager
```

# Recreate node-exporter container (to pick up new bind):
`docker compose up -d --no-deps --force-recreate node-exporter`

Moving the UFW log to a separate file on the storage partition and configuring rsyslog to write UFW messages there can help reduce wear on the SD card and centralize logs. Here's how you can set this up:

# Make sure the storage directory exists and set sensible perms
```
sudo mkdir -p /mnt/storage/logs
sudo chown root:adm /mnt/storage/logs
sudo chmod 0750 /mnt/storage/logs
```

# Ensure ufw.log exists on the storage partition and set ownership/perm
```
sudo touch /mnt/storage/logs/ufw.log
sudo chown root:adm /mnt/storage/logs/ufw.log
sudo chmod 0640 /mnt/storage/logs/ufw.log
```

If you are bind-mounting the file to `/var/log/ufw.log`, mount it now (or add to /etc/fstab)
Temporary bind-mount (immediate, not persistent)

`sudo mount --bind /mnt/storage/logs/ufw.log /var/log/ufw.log`

# Reload/restart rsyslog so it picks up the config and file handles
sudo systemctl daemon-reload
sudo systemctl restart rsyslog

Quick test: emit a kernel-level UFW test message, then show the tail of the log
```
sudo logger -p kern.warning "UFW TEST from $(hostname)"
sleep 1
sudo tail -n 50 /mnt/storage/logs/ufw.log || sudo tail -n 50 /var/log/ufw.log || true
```
