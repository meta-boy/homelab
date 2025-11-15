# Woodpecker CI

Woodpecker CI is a simple, lightweight, and self-hosted continuous integration and deployment platform.

## Deployment

This deployment consists of:
- Woodpecker Server: Web UI and API
- Woodpecker Agent: Runs CI/CD pipelines using Kubernetes backend

## Configuration

### Prerequisites

**IMPORTANT**: Woodpecker requires at least one Git forge to be configured before it can start.

#### Step 1: Create GitHub OAuth Application

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in the details:
   - **Application name**: Woodpecker CI
   - **Homepage URL**: https://woodpecker.is-up-in.space
   - **Authorization callback URL**: https://woodpecker.is-up-in.space/authorize
4. Click "Register application"
5. Copy the **Client ID** and generate a **Client Secret**

#### Step 2: Generate Agent Secret

```bash
openssl rand -hex 32
```

#### Step 3: Update Secret Configuration

Update `base/sealed-secret.yaml` with your credentials:

```yaml
stringData:
  agent-secret: "YOUR_GENERATED_AGENT_SECRET"
  github-client: "YOUR_GITHUB_CLIENT_ID"
  github-secret: "YOUR_GITHUB_CLIENT_SECRET"
  admin-user: "your-github-username"  # Optional: Makes you admin
```

#### Step 4: (Optional) Seal the Secret

If using sealed-secrets:
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

## Switching to a Different Forge

The deployment is pre-configured for GitHub. To use a different forge:

### Using Gitea

1. Create an OAuth2 application in your Gitea instance:
   - Go to Settings → Applications → Manage OAuth2 Applications
   - Redirect URI: `https://woodpecker.is-up-in.space/authorize`

2. Comment out GitHub configuration in `base/server-deployment.yaml` and uncomment Gitea lines

3. Update `base/sealed-secret.yaml`:
   ```yaml
   gitea-url: "https://gitea.example.com"
   gitea-client: "YOUR_GITEA_CLIENT_ID"
   gitea-secret: "YOUR_GITEA_CLIENT_SECRET"
   ```

### Using GitLab

Add to `base/server-deployment.yaml`:
```yaml
- name: WOODPECKER_GITLAB
  value: "true"
- name: WOODPECKER_GITLAB_URL
  value: "https://gitlab.com"
- name: WOODPECKER_GITLAB_CLIENT
  valueFrom:
    secretKeyRef:
      name: woodpecker-secret
      key: gitlab-client
- name: WOODPECKER_GITLAB_SECRET
  valueFrom:
    secretKeyRef:
      name: woodpecker-secret
      key: gitlab-secret
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
