# Woodpecker CI

Woodpecker CI is a simple, lightweight, and self-hosted continuous integration and deployment platform.

## Deployment

This deployment consists of:
- Woodpecker Server: Web UI and API
- Woodpecker Agent: Runs CI/CD pipelines using Kubernetes backend

## Configuration

### Prerequisites

Before deploying, you need to configure the secret for agent communication:

1. Generate a random agent secret:
```bash
openssl rand -hex 32
```

2. Update the `sealed-secret.yaml` file with the generated secret:
```yaml
agent-secret: "YOUR_GENERATED_SECRET"
```

3. (Optional) If you want to seal the secret using sealed-secrets:
```bash
kubeseal --format=yaml < base/sealed-secret.yaml > base/sealed-secret-encrypted.yaml
```

### Environment Variables

The server deployment is configured with:
- `WOODPECKER_HOST`: https://woodpecker.is-up-in.space
- `WOODPECKER_OPEN`: true (allows anyone to register)
- `WOODPECKER_AGENT_SECRET`: Shared secret for agent communication

The agent deployment uses:
- `WOODPECKER_BACKEND`: kubernetes (runs pipelines as Kubernetes pods)
- `WOODPECKER_BACKEND_K8S_NAMESPACE`: woodpecker
- `WOODPECKER_BACKEND_K8S_VOLUME_SIZE`: 10G

## Access

The Woodpecker UI is accessible at: https://woodpecker.is-up-in.space

## Architecture

### Server
- Handles web UI, API, and webhook processing
- Stores pipeline definitions and execution history
- Communicates with agents via gRPC (port 9000)
- Data persisted in a 10Gi PVC

### Agent
- Connects to the server via gRPC
- Executes pipeline steps as Kubernetes pods
- Uses Kubernetes backend for pipeline execution
- RBAC configured to manage pods and PVCs in the woodpecker namespace

## Forge Integration

To connect Woodpecker with your Git forge (GitHub, GitLab, Gitea, etc.), you need to:

1. Create an OAuth application in your forge
2. Update the server deployment with forge-specific environment variables:

For GitHub:
```yaml
- name: WOODPECKER_GITHUB
  value: "true"
- name: WOODPECKER_GITHUB_CLIENT
  value: "your-client-id"
- name: WOODPECKER_GITHUB_SECRET
  value: "your-client-secret"
```

For Gitea:
```yaml
- name: WOODPECKER_GITEA
  value: "true"
- name: WOODPECKER_GITEA_URL
  value: "https://gitea.example.com"
- name: WOODPECKER_GITEA_CLIENT
  value: "your-client-id"
- name: WOODPECKER_GITEA_SECRET
  value: "your-client-secret"
```

## Resources

- Official Documentation: https://woodpecker-ci.org/docs
- GitHub: https://github.com/woodpecker-ci/woodpecker
- Helm Charts: https://github.com/woodpecker-ci/helm

## Scaling

To scale the number of agents:
```bash
kubectl scale deployment woodpecker-agent -n woodpecker --replicas=5
```

Or update the `replicas` field in `agent-deployment.yaml`.
