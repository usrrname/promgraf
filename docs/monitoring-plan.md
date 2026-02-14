Lightweight Monitoring Plan for Raspberry Pi Home Server
=======================================================

Goal
----
Make it easy and reliable to monitor UFW (blocked connections) and Fail2ban (currently banned IPs) on a Raspberry Pi home NAS using Prometheus + Grafana — without adding Loki/Promtail. This version assumes `node_exporter`, `prometheus`, and `grafana` are running as Docker containers (either in one compose project or on the same Docker network).

Summary
-------
- Use Prometheus + Grafana for metric storage and dashboards.
- Run `prometheus-node-exporter` as a Docker container and enable the textfile collector via a host bind mount.
- Export UFW and Fail2ban state as Prometheus textfile metrics written by small host scripts into an on-disk directory mounted into the node_exporter container.
- Schedule scripts using systemd timers (or cron) on the host.
- Add Prometheus alerting rules (spike in UFW blocks, growing banned counts) and Grafana dashboards.

Why this approach with containers
--------------------------------
- You already run the monitoring stack in Docker; keeping node_exporter as a container reduces systemd/service footprint and keeps runtime consistent.
- The textfile collector still works: the node_exporter container reads `.prom` files from a host directory mounted into the container.
- Host scripts run on the Pi and write to that host directory — no need to run additional privileged containers to read logs.

High-level design (containerized node_exporter)
-----------------------------------------------
- Host:
  - Scripts live and run on the host (Raspberry Pi).
  - Scripts write `.prom` files to a directory on the host, e.g., `/var/lib/node_exporter/textfile_collector/`.
- Docker:
  - node_exporter container is started with a bind mount from `/var/lib/node_exporter/textfile_collector` on the host to the same path in the container.
  - node_exporter is started with `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector`.
  - Prometheus container scrapes node_exporter at `node_exporter:9100` (if in same compose network) or at the container's host-address:9100 (adjust per networking mode).
- Grafana reads Prometheus; dashboards and alerts operate as normal.

Directory and permission notes
------------------------------
- Create the textfile collector directory on the host:
  - `sudo mkdir -p /var/lib/node_exporter/textfile_collector`
- Node_exporter in the container must be able to read files in that directory.
  - If node_exporter runs as a named user (e.g., `node_exporter`) or a numeric UID in the container, make sure the host directory is readable by that UID/GID.
  - To discover the UID/GID used by your node_exporter image, run:
    - `docker exec -it <node_exporter_container> id -u` and `id -g` (or test with `docker run --rm <node_exporter_image> id -u`).
  - Then set ownership on the host directory accordingly, for example:
    - `sudo chown 65534:65534 /var/lib/node_exporter/textfile_collector` (if the container uses UID/GID 65534), or
    - `sudo chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector` if those names exist on the host.
  - As a fallback (less ideal), make the directory world-readable: `sudo chmod 755 /var/lib/node_exporter/textfile_collector`.

Example docker-compose snippet for node_exporter
-----------------------------------------------
If your monitoring stack is already in Docker Compose, add or update the `node_exporter` service. This example assumes the compose project includes `prometheus` and `grafana` and services are on the same user-defined network:

```/dev/null/docker-compose.node-exporter.example.yml#L1-80
version: "3.8"
services:
  node_exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    command:
      - '--collector.textfile.directory=/var/lib/node_exporter/textfile_collector'
    volumes:
      - /var/lib/node_exporter/textfile_collector:/var/lib/node_exporter/textfile_collector:ro
    ports:
      - "9100:9100"
    restart: unless-stopped
```