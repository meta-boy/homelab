# Docker Registry UI - Local Network Setup

This setup provides a private Docker registry with a web-based user interface using [Joxit's Docker Registry UI](https://github.com/Joxit/docker-registry-ui).

**Configuration**: Unauthenticated, NodePort access (local network only)

## Features

- 🌐 **Web UI**: Beautiful web interface to browse and manage images
- 🗑️ **Delete Images**: Delete images and tags directly from the UI
- 📊 **Image Details**: View image layers, history, and content digests
- 🎨 **Dark/Light Theme**: Auto-switching theme support
- 🏠 **Local Network Only**: Accessible only within your network via NodePort
- 🔓 **No Authentication**: Simplified setup for trusted networks

## Architecture

This deployment consists of two main components:

1. **Registry Server** (`registry:2.8.3`): The actual Docker registry that stores images
2. **Registry UI** (`joxit/docker-registry-ui`): Web interface that proxies to the registry

Both are exposed via NodePort for local network access.

## Prerequisites

- Kubernetes cluster with ArgoCD installed
- Local network access to Kubernetes nodes

## Network Ports

- **Registry UI**: NodePort `30800` (accessible at `http://<node-ip>:30800`)
- **Registry Server**: NodePort `30500` (accessible at `http://<node-ip>:30500`)

## Deployment

### Deploy via ArgoCD

```bash
# Apply the ArgoCD application
kubectl apply -f apps/docker-registry-ui-app.yaml

# Check the deployment status
kubectl get pods -n docker-registry
```

### Get Node IP

```bash
# Get your node IP
kubectl get nodes -o wide

# Look for the INTERNAL-IP column
```

## Access

### Web UI

Open your browser and navigate to:

```
http://<node-ip>:30800
```

Replace `<node-ip>` with your Kubernetes node's IP address.

### Registry API

The registry API is available at:

```
http://<node-ip>:30500
```

## Using the Registry

### Configure Docker Client

For an insecure registry (HTTP), add to `/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["<node-ip>:30500"]
}
```

Then restart Docker:

```bash
sudo systemctl restart docker
```

### Pushing Images

```bash
# 1. Tag your image
docker tag nginx:latest <node-ip>:30500/nginx:latest

# 2. Push the image
docker push <node-ip>:30500/nginx:latest

# 3. View it in the UI at http://<node-ip>:30800
```

### Pulling Images

```bash
# Pull from your registry
docker pull <node-ip>:30500/nginx:latest
```

### Using in Kubernetes

Reference images in your deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: <node-ip>:30500/my-image:latest
```

Or use the service name from within the cluster:

```yaml
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: registry-server.docker-registry.svc.cluster.local:5000/my-image:latest
```

## Configuration

### Registry Configuration

The registry is configured via `registry-config.yaml` with the following key features:

- **Storage**: Persistent storage using PVC (50Gi default)
- **Delete Enabled**: Allows deletion of images via API
- **No Authentication**: Open access within your network
- **CORS**: Configured for UI access

### UI Configuration

The UI is configured with these environment variables:

- `SINGLE_REGISTRY=true`: Fixed to single registry
- `DELETE_IMAGES=true`: Enable delete functionality in UI
- `SHOW_CONTENT_DIGEST=true`: Show SHA256 digests
- `REGISTRY_SECURED=false`: No authentication required
- `NGINX_PROXY_PASS_URL`: Proxies requests to avoid CORS issues
- `THEME=auto`: Auto dark/light theme

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

### Increase Storage

Edit `base/pvc.yaml` and change the storage size:

```yaml
resources:
  requests:
    storage: 100Gi  # Increase from 50Gi
```

## Troubleshooting

### Can't Access the UI

1. Check if pods are running:
   ```bash
   kubectl get pods -n docker-registry
   ```

2. Verify NodePort is exposed:
   ```bash
   kubectl get svc -n docker-registry
   ```

3. Check if your firewall allows the port:
   ```bash
   sudo firewall-cmd --list-ports  # If using firewalld
   ```

### Can't Push/Pull Images

1. Verify Docker daemon configuration:
   ```bash
   cat /etc/docker/daemon.json
   ```

2. Ensure the registry is in `insecure-registries`

3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```

4. Test connectivity:
   ```bash
   curl http://<node-ip>:30500/v2/_catalog
   ```

### Images Not Showing in UI

1. Check if images are actually in the registry:
   ```bash
   curl http://<node-ip>:30500/v2/_catalog
   ```

2. Check UI logs:
   ```bash
   kubectl logs -n docker-registry deployment/registry-ui
   ```

3. Check registry logs:
   ```bash
   kubectl logs -n docker-registry deployment/registry-server
   ```

## Security Considerations

⚠️ **Important**: This setup has NO authentication and is accessible to anyone on your network.

**Recommendations:**

1. **Network Isolation**: Ensure your Kubernetes cluster is on a trusted/isolated network
2. **Firewall Rules**: Use firewall rules to restrict access to the NodePorts
3. **VPN**: Consider requiring VPN access to your network
4. **Regular Backups**: Backup the registry PVC regularly

**For production environments**, consider adding:
- Authentication (htpasswd, OAuth2)
- TLS/HTTPS
- Network policies
- Ingress with authentication middleware

## Backup and Restore

### Backup

```bash
# Create a backup of the registry data
kubectl exec -n docker-registry deployment/registry-server -- \
  tar czf /tmp/registry-backup.tar.gz /var/lib/registry

# Copy the backup locally
kubectl cp docker-registry/<registry-server-pod>:/tmp/registry-backup.tar.gz ./registry-backup.tar.gz
```

### Restore

```bash
# Copy backup to pod
kubectl cp ./registry-backup.tar.gz docker-registry/<registry-server-pod>:/tmp/

# Extract backup
kubectl exec -n docker-registry deployment/registry-server -- \
  tar xzf /tmp/registry-backup.tar.gz -C /
```

## Quick Reference

| Component | Type | Port | URL |
|-----------|------|------|-----|
| **Registry UI** | NodePort | 30800 | http://\<node-ip\>:30800 |
| **Registry Server** | NodePort | 30500 | http://\<node-ip\>:30500 |
| **Registry (internal)** | ClusterIP | 5000 | registry-server.docker-registry.svc:5000 |

### Common Commands

```bash
# Get node IP
kubectl get nodes -o wide

# Check registry pods
kubectl get pods -n docker-registry

# Check services
kubectl get svc -n docker-registry

# View UI logs
kubectl logs -n docker-registry deployment/registry-ui -f

# View registry logs
kubectl logs -n docker-registry deployment/registry-server -f

# List images via API
curl http://<node-ip>:30500/v2/_catalog

# List tags for an image
curl http://<node-ip>:30500/v2/<image-name>/tags/list

# Run garbage collection
kubectl exec -n docker-registry deployment/registry-server -- \
  registry garbage-collect /etc/docker/registry/config.yml
```

## Resources

- [Docker Registry Documentation](https://docs.docker.com/registry/)
- [Joxit Docker Registry UI](https://github.com/Joxit/docker-registry-ui)
- [Docker Registry API](https://docs.docker.com/registry/spec/api/)

## Support

For issues related to:
- **Registry Server**: See [Docker Registry Issues](https://github.com/distribution/distribution/issues)
- **Registry UI**: See [Docker Registry UI Issues](https://github.com/Joxit/docker-registry-ui/issues)