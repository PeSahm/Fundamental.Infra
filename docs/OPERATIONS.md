# Operations Runbook

Day-to-day operations for the Fundamental platform.

---

## Daily Operations

### Check Pod Health
```bash
# All pods across all namespaces (filter out healthy ones)
microk8s kubectl get pods -A | grep -v Running | grep -v Completed

# Specific namespace
microk8s kubectl get pods -n fundamental-dev
microk8s kubectl get pods -n fundamental-prod
```

### View Logs
```bash
# Backend logs (last 100 lines, follow)
microk8s kubectl logs -n fundamental-dev -l app.kubernetes.io/component=backend --tail=100 -f

# Frontend logs
microk8s kubectl logs -n fundamental-dev -l app.kubernetes.io/component=frontend --tail=100

# PostgreSQL logs
microk8s kubectl logs -n fundamental-dev -l app.kubernetes.io/component=postgresql --tail=50

# Previous crash logs
microk8s kubectl logs -n fundamental-dev <POD_NAME> --previous
```

### Check ArgoCD Sync Status
```bash
microk8s kubectl get applications -n argocd
# Expected: Synced/Healthy for both fundamental-dev and fundamental-prod
```

---

## Deploying Code Changes

### Automatic (Normal Flow)
1. Push code to `develop` (dev) or `main` (prod)
2. GitHub Actions CI/CD automatically:
   - Builds and tests
   - Builds Docker image
   - Pushes to registry.academind.ir
   - Triggers repository_dispatch to Infra repo
3. ArgoCD detects the change and syncs

### Manual Deployment
```bash
# Trigger CI/CD manually
gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.Backend --ref develop -f environment=dev
gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.FrontEnd --ref develop -f environment=dev

# Or force ArgoCD sync
microk8s kubectl patch application fundamental-dev -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true}}}}}'
```

### Restart a Deployment
```bash
# Restart backend (picks up new config/secrets)
microk8s kubectl rollout restart deployment -n fundamental-dev -l app.kubernetes.io/component=backend

# Restart all deployments in a namespace
microk8s kubectl rollout restart deployment -n fundamental-dev
```

---

## Database Operations

### Backup
```bash
# Backup all environments
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/backup-database.yaml

# Backup specific environment
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/backup-database.yaml -e "target_env=prod"

# Download backup to local
scp root@5.10.248.55:/root/backups/latest-prod.sql.gz ./
```

### Restore
```bash
# Restore from latest backup
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/restore-database.yaml -e "target_env=dev"

# Restore from specific file
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/restore-database.yaml \
  -e "target_env=dev" -e "backup_file=/root/backups/dev-fundamental_dev-20260212-1430.sql.gz"
```

### Run Migrations Manually
```bash
# Check migrator job status
microk8s kubectl get jobs -n fundamental-dev

# Re-run migration (delete completed job, ArgoCD recreates)
microk8s kubectl delete job -n fundamental-dev -l app.kubernetes.io/component=migrator
```

### Connect to Database
```bash
# Get credentials
NS=fundamental-dev
DB_USER=$(microk8s kubectl get secret -n $NS postgresql-credentials -o jsonpath='{.data.username}' | base64 -d)
DB_PASS=$(microk8s kubectl get secret -n $NS postgresql-credentials -o jsonpath='{.data.password}' | base64 -d)
POD=$(microk8s kubectl get pods -n $NS -l app.kubernetes.io/component=postgresql -o jsonpath='{.items[0].metadata.name}')

# Interactive psql session
microk8s kubectl exec -it -n $NS $POD -- psql -U $DB_USER -d fundamental_dev
```

---

## Scaling

### Manual Replica Scaling
```bash
# Scale backend
microk8s kubectl scale deployment -n fundamental-prod -l app.kubernetes.io/component=backend --replicas=3

# Scale frontend
microk8s kubectl scale deployment -n fundamental-prod -l app.kubernetes.io/component=frontend --replicas=3
```

### Permanent Scaling (via config)
1. Edit `config.yaml` → `environments.prod.replicas.backend`
2. Run `./scripts/generate-config.sh`
3. Commit and push to trigger ArgoCD sync

### Add Worker Node
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/add-worker.yaml \
  -e "worker_ip=10.0.0.2" -e "worker_hostname=worker-1"
```

### Remove Worker Node
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/remove-worker.yaml \
  -e "worker_hostname=worker-1" -e "worker_ip=10.0.0.2"
```

---

## Credential Rotation

### Registry Password
```bash
# Generate new password
NEW_PASS=$(openssl rand -base64 32)

# Update htpasswd on VPS
htpasswd -b /etc/registry/htpasswd fundamental "$NEW_PASS"

# Update Kubernetes secrets in all namespaces
for NS in fundamental-dev fundamental-prod; do
  microk8s kubectl delete secret registry-credentials -n $NS
  microk8s kubectl create secret docker-registry registry-credentials -n $NS \
    --docker-server=registry.academind.ir \
    --docker-username=fundamental \
    --docker-password="$NEW_PASS"
done

# Update GitHub secrets
gh secret set REGISTRY_PASSWORD -R PeSahm/Fundamental.Backend --body "$NEW_PASS"
gh secret set REGISTRY_PASSWORD -R PeSahm/Fundamental.FrontEnd --body "$NEW_PASS"

# Save new password
echo "$NEW_PASS" > /root/.fundamental-credentials/registry-password
```

### Database Password
```bash
NS=fundamental-dev
DB=fundamental_dev
NEW_PASS=$(openssl rand -base64 24)

# Update in PostgreSQL
POD=$(microk8s kubectl get pods -n $NS -l app.kubernetes.io/component=postgresql -o jsonpath='{.items[0].metadata.name}')
microk8s kubectl exec -n $NS $POD -- psql -U fundamental -c "ALTER USER fundamental PASSWORD '$NEW_PASS';"

# Update Kubernetes secret
microk8s kubectl create secret generic postgresql-credentials -n $NS \
  --from-literal=username=fundamental \
  --from-literal=password="$NEW_PASS" \
  --from-literal=connection-string="Host=fundamental-$NS-fundamental-stack-postgresql;Database=$DB;Username=fundamental;Password=$NEW_PASS" \
  --dry-run=client -o yaml | microk8s kubectl apply -f -

# Restart backend to pick up new password
microk8s kubectl rollout restart deployment -n $NS -l app.kubernetes.io/component=backend
```

---

## Monitoring

### Resource Usage
```bash
# Node resource usage
microk8s kubectl top nodes

# Pod resource usage
microk8s kubectl top pods -n fundamental-prod --sort-by=memory
```

### Disk Space
```bash
df -h /
du -sh /root/backups/
du -sh /var/snap/microk8s/common/
```

### Check Certificates
```bash
# Certificate expiry
microk8s kubectl get certificates -A
# Detailed status
microk8s kubectl describe certificate -A
```

### ArgoCD Dashboard
- URL: https://argocd.academind.ir
- Username: `admin`
- Password: `cat /root/.fundamental-credentials/argocd-password.txt`

### Sentry Dashboard
- URL: https://sentry.academind.ir
- Credentials: See `/root/.fundamental-credentials/sentry-credentials.txt`

---

## Common Issues

### Pod Stuck in ImagePullBackOff
```bash
# Check registry connectivity
curl -u fundamental:$(cat /root/.fundamental-credentials/registry-password) \
  https://registry.academind.ir/v2/_catalog

# Check image exists
curl -u fundamental:$(cat /root/.fundamental-credentials/registry-password) \
  https://registry.academind.ir/v2/fundamental-backend/tags/list

# Check registry-credentials secret
microk8s kubectl get secret registry-credentials -n fundamental-dev -o yaml
```

### Backend CrashLoopBackOff
```bash
# Check logs
microk8s kubectl logs -n fundamental-dev -l app.kubernetes.io/component=backend --previous

# Common causes:
# - Database connection failed (check postgresql pod)
# - Missing environment variable (check secrets)
# - Assembly loading error (check Dockerfile build)
```

### Ingress Not Routing
```bash
# Check ingress resources
microk8s kubectl get ingress -A

# Check ingress controller
microk8s kubectl get pods -n ingress

# Check ingress logs
microk8s kubectl logs -n ingress -l name=nginx-ingress-microk8s
```

### CI/CD Build Failing
```bash
# Check runner status
systemctl status actions.runner.*

# Check recent runs
gh run list --repo PeSahm/Fundamental.Backend --limit 5

# View failed run logs
gh run view <RUN_ID> --repo PeSahm/Fundamental.Backend --log-failed
```

---

## Health Check Playbook

Run the comprehensive health check:
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/verify-deployment.yaml
```

This checks:
- MicroK8s cluster health
- All pods in all namespaces
- ArgoCD sync status
- TLS certificate validity
- HTTP endpoint accessibility
- Registry availability
