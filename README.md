# Homelab GitOps with ArgoCD

This repository contains Kubernetes manifests and Helm charts for a homelab environment managed by ArgoCD using GitOps principles.

## Architecture

```
homelab/
├── infrastructure/          # Core infrastructure components
│   ├── argocd/             # ArgoCD Helm chart and values
│   └── nginx-ingress/      # Nginx Ingress Controller
├── argocd-apps/            # ArgoCD Application manifests
│   ├── root-app.yaml       # App of Apps pattern
│   ├── argocd.yaml         # ArgoCD self-management
│   └── nginx-ingress.yaml  # Nginx Ingress application
└── bootstrap/              # Initial setup scripts
```

## Prerequisites

- Kubernetes cluster (k3s, microk8s, or any Kubernetes distribution)
- kubectl configured to access your cluster
- Helm 3.x installed
- Git repository (GitHub, GitLab, etc.)

## Initial Setup

### 1. Clone This Repository

```bash
git clone https://github.com/meta-boy/homelab.git
cd homelab
```

### 2. Install ArgoCD

Run the bootstrap script to install ArgoCD:

```bash
cd bootstrap
./install-argocd.sh
```

This will:
- Create the `argocd` namespace
- Install ArgoCD using Helm
- Display the initial admin password

### 3. Access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Visit http://localhost:8080 and login with:
- Username: `admin`
- Password: (from the bootstrap script output)

### 4. Bootstrap GitOps

Apply the root application to enable GitOps:

```bash
cd bootstrap
./bootstrap-gitops.sh
```

This will create the App of Apps pattern, and ArgoCD will automatically:
- Deploy Nginx Ingress Controller
- Manage itself (ArgoCD) via GitOps
- Monitor your Git repository for changes

## Cloudflare Tunnel Integration

The Nginx Ingress Controller is configured with `type: ClusterIP` to work with Cloudflare Tunnels.

### Configure Cloudflare Tunnel

On your Cloudflare Tunnel machine, configure the tunnel to point to your Nginx Ingress service:

```yaml
ingress:
  - hostname: argocd.yourdomain.com
    service: http://nginx-ingress-controller.ingress-nginx.svc.cluster.local:80
  - hostname: "*.yourdomain.com"
    service: http://nginx-ingress-controller.ingress-nginx.svc.cluster.local:80
  - service: http_status:404
```

### Update ArgoCD Domain

Update the ArgoCD domain in `infrastructure/argocd/values.yaml`:

```yaml
argo-cd:
  global:
    domain: argocd.yourdomain.com

  server:
    ingress:
      hosts:
        - argocd.yourdomain.com
```

Commit and push the changes - ArgoCD will automatically sync.

## Managing Applications

### Adding New Applications

1. Create Helm chart or Kubernetes manifests in a new directory
2. Create an ArgoCD Application manifest in `argocd-apps/`
3. Commit and push - ArgoCD will automatically deploy

Example Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/meta-boy/homelab.git
    targetRevision: HEAD
    path: apps/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Monitoring

Check application status:

```bash
kubectl get applications -n argocd
```

View application details:

```bash
kubectl describe application nginx-ingress -n argocd
```

## Useful Commands

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Port forward to Nginx Ingress (for local testing)
kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller 8081:80

# Sync all applications
kubectl patch application root-app -n argocd -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' --type merge

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server -f
```

## Customization

### ArgoCD

Edit `infrastructure/argocd/values.yaml` to customize ArgoCD settings.

### Nginx Ingress

Edit `infrastructure/nginx-ingress/values.yaml` to customize Nginx Ingress settings.

## Troubleshooting

### ArgoCD Not Syncing

Check the application status:

```bash
kubectl describe application <app-name> -n argocd
```

Force a sync:

```bash
kubectl patch application <app-name> -n argocd -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' --type merge
```

### Ingress Not Working

Check Nginx Ingress Controller logs:

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

Check ingress resources:

```bash
kubectl get ingress -A
```

## Security Notes

- The default configuration uses `server.insecure: true` for ArgoCD (no TLS). This is fine when using Cloudflare Tunnel which provides TLS termination.
- Change the default admin password after first login
- Consider setting up SSO/OIDC for ArgoCD in production
- Review and adjust RBAC settings as needed

## License

MIT
