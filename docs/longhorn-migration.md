# Longhorn Distributed Storage Migration

## Overview
Migrated production PostgreSQL database from single-node hostPath storage to Longhorn distributed storage with 3-way replication across a 4-node bare-metal Kubernetes cluster.

## Problem Statement
**Before Migration:**
- PostgreSQL data stored using hostPath on a single node (worker-node-3)
- Single point of failure - if worker-node-3 went down, database became unavailable
- No data redundancy
- Manual node affinity required to keep pod on specific node

**Impact:** Critical business application (production business website) at risk of downtime from single node failure.

## Solution Architecture

### Longhorn Distributed Storage
- **Deployment Method:** ArgoCD (GitOps)
- **Replication Factor:** 3 replicas across different nodes
- **Storage Class:** `longhorn` (set as default)
- **Data Engine:** v1
- **Version:** v1.10.1

### Architecture Benefits
1. **High Availability:** Data replicated to 3 nodes (worker-node-1, worker-node-2, worker-node-3)
2. **Automatic Failover:** Pod can reschedule to any node with instant data access
3. **Zero Single Points of Failure:** Survives individual node failures
4. **GitOps Managed:** Infrastructure as code via ArgoCD

## Implementation

### Prerequisites
All nodes required `open-iscsi` and `nfs-common` packages:
```bash
# Installed on all 4 nodes (control-plane-node, worker-node-1, worker-node-2, worker-node-3)
sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

### Longhorn Installation
Deployed via ArgoCD application manifest in `longhorn/overlays/production/longhorn-app.yaml`:

**Key Configuration:**
- `defaultReplicaCount: 3` - Ensures 3 replicas for all volumes
- `defaultClass: true` - Makes Longhorn the default StorageClass
- Automated sync enabled for continuous deployment

### Database Migration Process

**1. Backup Current Database**
```bash
./scripts/backup-db.sh
# Backup size: 48K
```

**2. Scale Down Application**
```bash
kubectl scale deployment app-backend -n production --replicas=0
```

**3. Remove Old Storage**
```bash
kubectl delete deployment app-postgres -n production
kubectl delete pvc app-postgres-pvc -n production
```

**4. Update Manifest**
Changed from hostPath PV/PVC to Longhorn StorageClass:

**Before:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-postgres-pv
spec:
  hostPath:
    path: /mnt/data/app-postgres
---
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  selector:
    matchLabels:
      app: postgres
```

**After:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-postgres-pvc
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

**5. Deploy with Longhorn**
```bash
git add k8s/01-postgres.yaml
git commit -m "Migrate PostgreSQL to Longhorn distributed storage"
git push origin main
# ArgoCD auto-synced and deployed
```

**6. Restore Database**
```bash
kubectl exec -n production deployment/app-postgres -i -- \
  psql -U postgres_user -d appdb < backup.sql
```

**7. Verify and Scale Up**
```bash
kubectl scale deployment app-backend -n production --replicas=2
curl -I https://example.com  # HTTP/2 200
```

## Results

### Replica Distribution
```bash
kubectl get replicas.longhorn.io -n longhorn-system
```

**Output:**
```
NAME                    NODE           STATE     AGE
pvc-...-r-1c9fbd3d     worker-node-3         running   15m
pvc-...-r-779e05b9     worker-node-1   running   15m
pvc-...-r-e1356379     worker-node-2         running   15m
```

### Volume Status
```bash
kubectl get volume.longhorn.io -n longhorn-system
```

**Output:**
```
NAME                STATE      ROBUSTNESS   SIZE          NODE
pvc-c1cc0554-...    attached   healthy      10737418240   worker-node-3
```

**Key Metrics:**
- ✅ 3 replicas distributed across 3 nodes
- ✅ Volume state: attached, healthy
- ✅ Zero data loss during migration
- ✅ Website uptime: maintained (frontend remained accessible)
- ✅ Total migration time: ~25 minutes

## Troubleshooting Encountered

### Issue 1: Longhorn Manager CrashLoopBackOff
**Error:**
```
failed to check environment, please make sure you have iscsiadm/open-iscsi installed
```

**Resolution:**
Installed `open-iscsi` package on all nodes:
```bash
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

### Issue 2: PVC Spec Immutability
**Error:**
```
PersistentVolumeClaim "app-postgres-pvc" is invalid: spec: Forbidden: 
spec is immutable after creation except resources.requests
```

**Resolution:**
Deleted existing PVC before applying updated manifest with `storageClassName: longhorn`.

## Lessons Learned

1. **Prerequisites Matter:** Always verify dependencies (iscsid) across all nodes before deploying storage solutions
2. **PVC Immutability:** Cannot change StorageClass on existing PVC - must delete and recreate
3. **Backup First:** Database backup before migration is non-negotiable
4. **GitOps Benefits:** ArgoCD automated the entire deployment after manifest update
5. **Verification Steps:** Always check replica distribution and volume health post-migration

## Future Enhancements

- [ ] Migrate remaining applications to Longhorn
- [ ] Configure Longhorn backups to external storage (S3/NFS)
- [ ] Set up Longhorn UI for visual monitoring
- [ ] Implement automated snapshot schedules
- [ ] Test failover scenarios (node shutdown testing)

## References

- [Longhorn Documentation](https://longhorn.io/docs/)
- [ArgoCD Installation Guide](https://argo-cd.readthedocs.io/en/stable/)
- Application manifests: `longhorn/overlays/production/`

---

**Migration Date:** December 22, 2025  
**Application:** Production business application  
**Cluster:** 4-node bare-metal Kubernetes (Ubuntu 24.04, k8s v1.33.3)
