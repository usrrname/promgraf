# Prometheus + Alertmanager + Grafana with Docker Compose

HomeNAS monitoring for my Pi 4 NAS using:
- Prometheus `localhost:9090` w/remote write to Grafana Cloud 
- Grafana `localhost:3000`
- Docker Compose
- [] :construction: Alertmanager with email notifications `localhost:9093`

Listening for 
- Node Exporter metrics on port `9100`
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
