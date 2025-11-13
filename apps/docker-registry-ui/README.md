# Docker Registry UI with Authentication

This setup provides a private Docker registry with a web-based user interface using [Joxit's Docker Registry UI](https://github.com/Joxit/docker-registry-ui).

## Features

- 🔒 **Secure**: Basic authentication (htpasswd) for registry access
- 🌐 **Web UI**: Beautiful web interface to browse and manage images
- 🗑️ **Delete Images**: Delete images and tags directly from the UI
- 📊 **Image Details**: View image layers, history, and content digests
- 🎨 **Dark/Light Theme**: Auto-switching theme support

## Architecture

This deployment consists of two main components:

1. **Registry Server** (`registry:2.8.3`): The actual Docker registry that stores images
2. **Registry UI** (`joxit/docker-registry-ui`): Web interface that proxies to the registry

## Prerequisites

- Kubernetes cluster with ArgoCD installed
- `kubeseal` CLI for creating sealed secrets
- `openssl` utility for generating credentials (pre-installed on most Linux distributions)

## Initial Setup

### 1. Generate htpasswd Credentials

First, create a username and password for registry authentication:

```bash
# Generate htpasswd entry using OpenSSL (replace 'admin' and 'yourpassword' with your credentials)
# OpenSSL is pre-installed on most Linux distributions
echo "admin:$(openssl passwd -6 'yourpassword')" > htpasswd
```

### 2. Create and Seal the Secret

Create a Kubernetes secret and seal it:

```bash
# Create the secret (do NOT apply this directly)
kubectl create secret generic registry-auth \
  --from-file=htpasswd=./htpasswd \
  --namespace=docker-registry \
  --dry-run=client -o yaml > registry-secret.yaml

# Seal the secret
kubeseal --format=yaml < registry-secret.yaml > sealed-secret.yaml

# Copy the encryptedData section from sealed-secret.yaml to:
# apps/docker-registry-ui/base/sealed-secret.yaml
```

### 3. Update the Sealed Secret

Replace the `REPLACE_WITH_SEALED_HTPASSWD_DATA` placeholder in `sealed-secret.yaml` with your actual sealed data.

### 4. Update the Ingress Host

Edit `apps/docker-registry-ui/base/ingress.yaml` and change the host to your domain:

```yaml
spec:
  rules:
  - host: registry.your-domain.com  # Change this to your domain
```

### 5. Deploy via ArgoCD

```bash
# Apply the ArgoCD application
kubectl apply -f apps/docker-registry-ui-app.yaml

# Check the deployment status
kubectl get pods -n docker-registry
```

## Usage

### Accessing the Web UI

Navigate to your configured domain (e.g., `https://registry.your-domain.com`). You'll be prompted for credentials when accessing the registry.

### Pushing Images

To push images to your private registry:

```bash
# 1. Log in to your registry
docker login registry.your-domain.com

# 2. Tag your image
docker tag my-image:latest registry.your-domain.com/my-image:latest

# 3. Push the image
docker push registry.your-domain.com/my-image:latest
```

### Pulling Images

```bash
# Log in if not already authenticated
docker login registry.your-domain.com

# Pull the image
docker pull registry.your-domain.com/my-image:latest
```

### Using in Kubernetes

To pull images from your private registry in Kubernetes, create an image pull secret:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.your-domain.com \
  --docker-username=admin \
  --docker-password=yourpassword \
  --namespace=your-namespace
```

Then reference it in your pod/deployment:

```yaml
spec:
  imagePullSecrets:
  - name: regcred
  containers:
  - name: my-app
    image: registry.your-domain.com/my-image:latest
```

## Configuration

### Registry Configuration

The registry is configured via `registry-config.yaml` with the following key features:

- **Storage**: Persistent storage using PVC (50Gi default)
- **Delete Enabled**: Allows deletion of images via API
- **Authentication**: Basic auth using htpasswd
- **CORS**: Configured for UI access

### UI Configuration

The UI is configured with these environment variables:

- `SINGLE_REGISTRY=true`: Fixed to single registry (your private registry)
- `DELETE_IMAGES=true`: Enable delete functionality in UI
- `SHOW_CONTENT_DIGEST=true`: Show SHA256 digests
- `REGISTRY_SECURED=true`: Indicates registry uses authentication
- `NGINX_PROXY_PASS_URL`: Proxies requests to avoid CORS issues

## Storage Management

### Check Storage Usage

```bash
kubectl exec -n docker-registry deployment/registry-server -- du -sh /var/lib/registry
```

### Run Garbage Collection

After deleting images from the UI, run garbage collection to free up space:

```bash
kubectl exec -n docker-registry deployment/registry-server -- \
  registry garbage-collect /etc/docker/registry/config.yml
```

Or set up a CronJob for automatic garbage collection:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: registry-gc
  namespace: docker-registry
spec:
  schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: gc
            image: registry:2.8.3
            command:
            - registry
            - garbage-collect
            - /etc/docker/registry/config.yml
            volumeMounts:
            - name: registry-data
              mountPath: /var/lib/registry
            - name: registry-config
              mountPath: /etc/docker/registry
          volumes:
          - name: registry-data
            persistentVolumeClaim:
              claimName: registry-data
          - name: registry-config
            configMap:
              name: registry-config
          restartPolicy: OnFailure
```

## Troubleshooting

### Authentication Issues

If you're having trouble logging in:

1. Check the htpasswd secret is correctly mounted:
   ```bash
   kubectl exec -n docker-registry deployment/registry-server -- cat /auth/htpasswd
   ```

2. Verify the registry logs:
   ```bash
   kubectl logs -n docker-registry deployment/registry-server
   ```

### UI Not Loading

1. Check if the UI can reach the registry:
   ```bash
   kubectl logs -n docker-registry deployment/registry-ui
   ```

2. Verify the NGINX_PROXY_PASS_URL is correct

### Push/Pull Failures

1. Ensure you're logged in:
   ```bash
   docker login registry.your-domain.com
   ```

2. Check registry server logs for errors:
   ```bash
   kubectl logs -n docker-registry deployment/registry-server -f
   ```

### CORS Errors

The current setup uses `NGINX_PROXY_PASS_URL` which eliminates CORS issues by proxying requests through the UI. If you still see CORS errors:

1. Check the registry CORS configuration in `registry-config.yaml`
2. Verify the UI's proxy settings
3. Check browser console for specific CORS error messages

## Security Considerations

1. **HTTPS**: Always use HTTPS in production (configured via Traefik in this setup)
2. **Strong Passwords**: Use strong passwords for htpasswd authentication
3. **Network Policies**: Consider implementing Kubernetes NetworkPolicies
4. **Regular Updates**: Keep registry and UI images updated
5. **Backup**: Regularly backup the registry PVC data

## Backup and Restore

### Backup

```bash
# Create a backup of the registry data
kubectl exec -n docker-registry deployment/registry-server -- \
  tar czf /tmp/registry-backup.tar.gz /var/lib/registry

# Copy the backup locally
kubectl cp docker-registry/registry-server-xxx:/tmp/registry-backup.tar.gz ./registry-backup.tar.gz
```

### Restore

```bash
# Copy backup to pod
kubectl cp ./registry-backup.tar.gz docker-registry/registry-server-xxx:/tmp/

# Extract backup
kubectl exec -n docker-registry deployment/registry-server -- \
  tar xzf /tmp/registry-backup.tar.gz -C /
```

## Monitoring

You can monitor the registry with Prometheus metrics. The registry exposes metrics at `/metrics` endpoint. Add this to your Prometheus scrape config:

```yaml
- job_name: 'docker-registry'
  static_configs:
  - targets: ['registry-server.docker-registry.svc.cluster.local:5000']
```

## Resources

- [Docker Registry Documentation](https://docs.docker.com/registry/)
- [Joxit Docker Registry UI](https://github.com/Joxit/docker-registry-ui)
- [Docker Registry API](https://docs.docker.com/registry/spec/api/)

## Support

For issues related to:
- **Registry Server**: See [Docker Registry Issues](https://github.com/distribution/distribution/issues)
- **Registry UI**: See [Docker Registry UI Issues](https://github.com/Joxit/docker-registry-ui/issues)