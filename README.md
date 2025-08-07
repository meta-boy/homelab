# Homelab Kubernetes Applications

This repository contains Helm charts and manifests for deploying and managing homelab applications on Kubernetes.

## Structure
- **applications/**: Standalone application manifests (YAML).
- **charts/**: Helm charts for modular, reusable deployments.
  - `adguard/`: Example chart for AdGuard Home, including templates and values.

## Features
- Easy deployment of homelab services
- Customizable Helm charts
- Example manifests for quick setup
- MetalLB load balancer support for bare-metal Kubernetes networking
- Designed for lightweight clusters using k3s

## Getting Started
1. Clone the repository:
   ```bash
   git clone https://github.com/meta-boy/homelab.git
   cd homelab
   ```
2. Install [Helm](https://helm.sh/).
3. Deploy a chart:
   ```bash
   helm install adguard ./charts/adguard -f charts/adguard/values.yaml
   ```

## Contributing
Pull requests and suggestions are welcome!

## License
MIT
