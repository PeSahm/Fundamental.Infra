# Disaster Recovery Runbook

Recovery procedures for the Fundamental platform.

---

## 1. Complete VPS Loss

If the VPS is completely lost (hardware failure, provider issue):

### Recovery Steps

1. **Provision new VPS** (Ubuntu 22.04+, min 4GB RAM, 50GB disk)
2. **Add SSH key** to the new VPS
3. **Update DNS** in Cloudflare to point to new VPS IP (or let bootstrap handle it)
4. **Run bootstrap**:
   ```bash
   ssh root@<NEW_VPS_IP>
   git clone https://github.com/PeSahm/Fundamental.Infra.git
   cd Fundamental.Infra
   # Update config.yaml with new IP if needed
   ./scripts/bootstrap.sh --role control-plane
   ```
5. **Restore database** from backup (if you have one):
   ```bash
   # Copy backup to new VPS
   scp ./latest-prod.sql.gz root@<NEW_VPS_IP>:/root/backups/
   # Restore
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/restore-database.yaml \
     -e "target_env=prod" -e "backup_file=/root/backups/latest-prod.sql.gz"
   ```
6. **Verify**: Run `ansible/playbooks/verify-deployment.yaml`

### Data Loss Assessment
- **Source code**: Safe (GitHub)
- **Docker images**: Safe (rebuilt by CI/CD)
- **Infrastructure config**: Safe (Fundamental.Infra repo)
- **Database data**: Lost unless backed up (see backup section below)
- **Sentry history**: Lost (non-critical, rebuilt from scratch)
- **TLS certificates**: Re-issued automatically by cert-manager

---

## 2. Database Recovery

### Automated Backups
Daily backups run via systemd timer to `/root/backups/`:
```bash
# Check backup status
ls -lh /root/backups/

# Manual backup
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/backup-database.yaml
```

### Restore from Backup
```bash
# Restore dev from latest backup
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/restore-database.yaml \
  -e "target_env=dev"

# Restore prod from specific backup
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/restore-database.yaml \
  -e "target_env=prod" -e "backup_file=/root/backups/prod-fundamental_prod-20260212-1430.sql.gz"
```

### Download Backups to Local Machine
```bash
scp root@5.10.248.55:/root/backups/latest-dev.sql.gz ./
scp root@5.10.248.55:/root/backups/latest-prod.sql.gz ./
```

### PostgreSQL Pod Recovery
If the PostgreSQL pod itself is corrupted:
```bash
# Delete the PVC (WARNING: deletes all data)
microk8s kubectl delete pvc data-fundamental-prod-fundamental-stack-postgresql-0 -n fundamental-prod
# ArgoCD will recreate the StatefulSet and PVC
# Then restore from backup
```

---

## 3. Certificate Issues

### Symptoms
- Browser shows certificate error
- `kubectl get certificates -A` shows `False` in READY column

### Recovery
```bash
# Check certificate status
microk8s kubectl get certificates -A
microk8s kubectl describe certificate <NAME> -n <NAMESPACE>

# Check cert-manager logs
microk8s kubectl logs -n cert-manager deploy/cert-manager

# Force re-issue by deleting the certificate (cert-manager will recreate)
microk8s kubectl delete certificate dev-academind-ir-tls -n fundamental-dev
microk8s kubectl delete certificate sahmbaz-ir-tls -n fundamental-prod

# Verify Let's Encrypt cluster issuer
microk8s kubectl get clusterissuer letsencrypt-prod -o yaml
```

### Common Issues
- **Rate limiting**: Let's Encrypt limits 5 duplicate certs per week. Wait and retry.
- **DNS not propagated**: Ensure Cloudflare A records point to VPS IP.
- **HTTP-01 challenge fails**: Port 80 must be open. Check UFW: `ufw status`

---

## 4. ArgoCD Recovery

### ArgoCD Pod Issues
```bash
# Check ArgoCD pods
microk8s kubectl get pods -n argocd

# Restart ArgoCD
microk8s kubectl rollout restart deployment -n argocd argocd-server
microk8s kubectl rollout restart deployment -n argocd argocd-repo-server
microk8s kubectl rollout restart deployment -n argocd argocd-application-controller
```

### ArgoCD Complete Reinstall
```bash
# Re-run the ArgoCD playbook
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy-argocd.yaml

# Re-apply application manifests
microk8s kubectl apply -f argocd/applications/fundamental-dev.yaml
microk8s kubectl apply -f argocd/applications/fundamental-prod.yaml
```

### Application Stuck in Sync
```bash
# Force refresh
argocd app get fundamental-dev --hard-refresh
argocd app sync fundamental-dev --force

# Or delete and recreate
microk8s kubectl delete application fundamental-dev -n argocd
microk8s kubectl apply -f argocd/applications/fundamental-dev.yaml
```

### Recover ArgoCD Password
```bash
# Get initial admin password
microk8s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## 5. Sentry Recovery

Sentry data is not critical (error logs only). Full clean restart is acceptable.

### Kafka Cluster ID Mismatch
```bash
# Scale down Kafka
microk8s kubectl scale deployment sentry-kafka -n sentry --replicas=0
# Delete Kafka PVC
microk8s kubectl delete pvc -n sentry -l app=sentry-kafka
# Scale back up
microk8s kubectl scale deployment sentry-kafka -n sentry --replicas=1
```

### Redis OOM Crashes
```bash
# Get Redis pod
POD=$(microk8s kubectl get pods -n sentry -l app=sentry-redis -o jsonpath='{.items[0].metadata.name}')
# Get Redis password
PASS=$(microk8s kubectl get secret sentry-secrets -n sentry -o jsonpath='{.data.redis-password}' | base64 -d)
# Flush data and set memory limits
microk8s kubectl exec -n sentry $POD -- redis-cli -a "$PASS" FLUSHALL
microk8s kubectl exec -n sentry $POD -- redis-cli -a "$PASS" CONFIG SET maxmemory 384mb
microk8s kubectl exec -n sentry $POD -- redis-cli -a "$PASS" CONFIG SET maxmemory-policy allkeys-lru
```

### Full Sentry Reset
```bash
# Delete entire Sentry namespace and redeploy
microk8s kubectl delete namespace sentry
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy-sentry.yaml
```

---

## 6. GitHub Actions Runner Recovery

### Re-register Runner
```bash
# Remove old runner
cd /root/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove --token $(gh api repos/PeSahm/Fundamental.Backend/actions/runners/registration-token -q '.token')

# Register new runner
TOKEN=$(gh api -X POST repos/PeSahm/Fundamental.Backend/actions/runners/registration-token -q '.token')
./config.sh --url https://github.com/PeSahm/Fundamental.Backend --token $TOKEN \
  --name "vps-runner" --labels "self-hosted,Linux,X64,Iran" --unattended
sudo ./svc.sh install
sudo ./svc.sh start
```

---

## 7. DNS Issues

### Verify DNS Records
```bash
# Check what DNS resolves to
nslookup dev.academind.ir
nslookup sahmbaz.ir

# Check Cloudflare records via API
CLOUDFLARE_TOKEN="<your-token>"
ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=academind.ir" \
  -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq -r '.result[0].id')
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq '.result[] | {name, content, proxied}'
```

### Fix DNS Records
```bash
# Re-run Cloudflare Terraform
cd infrastructure/live/cloudflare
terragrunt apply
```

---

## 8. Worker Node Failure

### Remove Failed Node
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/remove-worker.yaml \
  -e "worker_hostname=worker-1" -e "worker_ip=10.0.0.2" -e "force=true"
```

### Replace with New Node
```bash
# On new worker VPS:
./scripts/bootstrap.sh --role worker --join-token <TOKEN>
```

---

## Backup Checklist

Regularly verify these items are backed up:

| Item | Location | Frequency |
|------|----------|-----------|
| Database (dev + prod) | `/root/backups/` | Daily (automated) |
| Credentials | `/root/.fundamental-credentials/` | After changes |
| Infrastructure code | GitHub (Fundamental.Infra) | Every push |
| Application code | GitHub (Backend, Frontend) | Every push |

### Download All Backups
```bash
scp -r root@5.10.248.55:/root/backups/ ./backups-$(date +%Y%m%d)/
scp -r root@5.10.248.55:/root/.fundamental-credentials/ ./credentials-backup/
```
