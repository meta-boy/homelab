# Homelab Kubernetes Applications

This repository contains Helm charts and manifests for deploying and managing homelab applications on Kubernetes.

## Structure
- **applications/**: Standalone application manifests (YAML).
- **charts/**: Helm charts for modular, reusable deployments.
  - `adguard/`: Chart for AdGuard Home DNS filtering, including templates and values.
  - `postgres/`: Chart for PostgreSQL database with persistence and LoadBalancer support.

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
   
   # Deploy PostgreSQL
   helm install postgres ./charts/postgres -f charts/postgres/values.yaml
   ```

## Contributing
Pull requests and suggestions are welcome!

## License
MIT
