# Temporal Service

Temporal workflow orchestration service for the homelab.

## Architecture

- **Temporal Server**: Workflow orchestration engine (temporalio/auto-setup:1.22.4)
- **Temporal UI**: Web interface for monitoring workflows (temporalio/ui:2.31.1)
- **Database**: Uses shared postgres instance at `postgres.postgres.svc.cluster.local:5432`

## Access

- **Temporal Server**: `temporal.temporal.svc.cluster.local:7233` (ClusterIP)
- **Temporal Server (External)**: `<node-ip>:30233` (NodePort via Tailscale)
- **Temporal UI**: `<node-ip>:30088` (NodePort via Tailscale)

## Database Setup

Before deploying Temporal, you need to create the `temporal` database in your postgres instance.

### Option 1: Using kubectl exec

```bash
# Connect to postgres pod
kubectl exec -it -n postgres postgres-0 -- psql -U <postgres-user>

# Create the temporal database
CREATE DATABASE temporal;

# Grant privileges (if needed)
GRANT ALL PRIVILEGES ON DATABASE temporal TO <postgres-user>;

# Verify
\l
\q
```

### Option 2: Using psql from local machine

```bash
# Port forward to postgres
kubectl port-forward -n postgres svc/postgres 5432:5432

# In another terminal
psql -h localhost -p 5432 -U <postgres-user>

# Create database
CREATE DATABASE temporal;
\q
```

### Option 3: Create a Kubernetes Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: temporal-db-init
  namespace: postgres
spec:
  template:
    spec:
      containers:
      - name: psql
        image: postgres:16
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        command:
        - psql
        - -h
        - postgres.postgres.svc.cluster.local
        - -U
        - <postgres-user>
        - -c
        - CREATE DATABASE temporal;
      restartPolicy: Never
  backoffLimit: 3
```

## Sealed Secrets

Before deployment, you need to seal the postgres credentials in `sealed-secret.yaml`:

```bash
# Create a temporary secret file
cat <<EOF > /tmp/temporal-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: temporal-secret
  namespace: temporal
type: Opaque
stringData:
  DB: "postgres12"
  DB_PORT: "5432"
  POSTGRES_USER: "<your-postgres-username>"
  POSTGRES_PWD: "<your-postgres-password>"
  POSTGRES_SEEDS: "postgres.postgres.svc.cluster.local"
  DBNAME: "temporal"
EOF

# Seal the secret
kubeseal --format=yaml < /tmp/temporal-secret.yaml > apps/temporal/base/sealed-secret.yaml

# Clean up
rm /tmp/temporal-secret.yaml
```

## Deployment

Once the database is created and secrets are sealed, ArgoCD will automatically deploy Temporal.

## Verification

Check that Temporal is running:

```bash
# Check pods
kubectl get pods -n temporal

# Check services
kubectl get svc -n temporal

# View logs
kubectl logs -n temporal -l app=temporal

# Access UI via port-forward (if not using NodePort)
kubectl port-forward -n temporal svc/temporal-ui 8088:8080
# Open http://localhost:8088
```

## Usage

Workers can connect to Temporal using:

```python
from temporalio.client import Client

client = await Client.connect("temporal.temporal.svc.cluster.local:7233")
```

Or via environment variable:
```bash
TEMPORAL_ADDRESS=temporal.temporal.svc.cluster.local:7233
```
