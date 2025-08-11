# Homelab Kubernetes Applications

This repository contains Helm charts and manifests for deploying and managing homelab applications on Kubernetes.

## Structure
- **applications/**: Standalone application manifests (YAML).
- **charts/**: Helm charts for modular, reusable deployments.
  - `adguard/`: Chart for AdGuard Home DNS filtering, including templates and values.
  - `grafana/`: Chart for Grafana monitoring and visualization platform.
  - `postgres/`: Chart for PostgreSQL database with persistence and LoadBalancer support.
  - `prometheus/`: Chart for Prometheus metrics collection and monitoring.
  - `pushgateway/`: Chart for Prometheus Pushgateway for short-lived job metrics.

## Features
- Easy deployment of homelab services
- Customizable Helm charts
- Example manifests for quick setup
- MetalLB load balancer support for bare-metal Kubernetes networking
- Designed for lightweight clusters using k3s

## Available Applications

### AdGuard Home
DNS filtering and ad blocking solution for your homelab network.
- **Chart**: `charts/adguard/`
- **Features**: Web UI, DNS filtering, DHCP server support
- **Deployment**: Includes ingress and service configurations

### Grafana
Monitoring and observability platform with customizable dashboards.
- **Chart**: `charts/grafana/`
- **Features**: Data visualization, dashboard management, alerting
- **Deployment**: Includes ingress and service configurations
- **Integration**: Works with Prometheus for metrics collection

### Prometheus
Time-series database and monitoring system for metrics collection.
- **Chart**: `charts/prometheus/`
- **Features**: Metrics scraping, PromQL queries, alerting rules
- **Deployment**: Includes persistence, RBAC, and service configurations
- **Integration**: Provides data source for Grafana dashboards

### Pushgateway
Prometheus component for collecting metrics from short-lived jobs.
- **Chart**: `charts/pushgateway/`
- **Features**: Metrics collection for batch jobs, ephemeral services
- **Deployment**: Includes ingress and service configurations
- **Integration**: Works with Prometheus for metrics aggregation

### PostgreSQL
Production-ready PostgreSQL database with persistence.
- **Chart**: `charts/postgres/`
- **Features**: Persistent storage (Longhorn), LoadBalancer service, configurable resources
- **Version**: PostgreSQL 17
- **Storage**: 4Gi default with Longhorn storage class
- **Network**: LoadBalancer with configurable IP (192.168.29.243)

## Getting Started
1. Clone the repository:
   ```bash
   git clone https://github.com/meta-boy/homelab.git
   cd homelab
   ```
2. Install [Helm](https://helm.sh/).
3. Deploy a chart:
   ```bash
   # Deploy AdGuard Home
   helm install adguard ./charts/adguard -f charts/adguard/values.yaml
   
   # Deploy Grafana
   helm install grafana ./charts/grafana -f charts/grafana/values.yaml
   
   # Deploy Prometheus
   helm install prometheus ./charts/prometheus -f charts/prometheus/values.yaml
   
   # Deploy Pushgateway
   helm install pushgateway ./charts/pushgateway -f charts/pushgateway/values.yaml
   
   # Deploy PostgreSQL
   helm install postgres ./charts/postgres -f charts/postgres/values.yaml
   ```

## Contributing
Pull requests and suggestions are welcome!

## License
MIT
