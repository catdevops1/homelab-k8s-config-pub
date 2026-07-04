# Cloudflare Tunnel Migration: systemd → In-Cluster Deployment

## Overview
Migrated Cloudflare Tunnel from a systemd service running on a single node to a resilient, multi-replica Kubernetes Deployment managed by ArgoCD, with credentials stored in HashiCorp Vault.

## Problem Statement
**Before Migration:**
- `cloudflared` ran as a systemd service on a single node (the control plane)
- Single point of failure — if that node went down, ALL public traffic stopped, even if the rest of the cluster was healthy
- Manual config management — editing `/etc/cloudflared/config.yml` by hand, no version control, no audit trail
- Invisible to GitOps — ArgoCD had no awareness of this critical piece of the traffic path, no drift detection, no self-heal

**Impact:** Every public-facing hostname (production business site, portfolio, ArgoCD dashboard, monitoring) routed through one process on one machine. A single node failure or accidental service stop meant total public outage.

## Solution Architecture

### In-Cluster, Multi-Replica Deployment
- **Deployment Method:** ArgoCD (GitOps)
- **Replicas:** 2 pods spread across different physical nodes
- **Scheduling:** `topologySpreadConstraints` with `DoNotSchedule` — Kubernetes will not place both replicas on the same node
- **Credentials:** Vault → External Secrets Operator → Kubernetes Secret (auto-refreshed hourly)
- **Config:** Plain ConfigMap (routing rules are not sensitive)

### Architecture (After)

```
Internet → Cloudflare Edge → Tunnel (2 connectors, different nodes)
                                      │
                                      ▼
                          MetalLB (LoadBalancer IP)
                                      │
                                      ▼
                              Envoy Gateway
                                      │
                                      ▼
                          HTTPRoute → Service → Pods
```

Cloudflare Tunnels support multiple simultaneous connectors on the same tunnel ID. Both pods register as independent, active connectors — Cloudflare's edge load-balances across whichever are healthy. Losing any single node no longer takes down public access.

### What's Secret vs. Not

| Item | Sensitive? | Where it lives |
|---|---|---|
| Tunnel ID | No — identifier, not a credential | ConfigMap, committed to git |
| Ingress routing rules (hostname → service) | No | ConfigMap, committed to git |
| Tunnel credentials JSON | **Yes** — grants ability to authenticate as the tunnel | Vault → ExternalSecret → K8s Secret (never git) |

## Implementation

### Repository Structure

```
cloudflared/
├── namespace.yaml          # cloudflared namespace
├── configmap.yaml          # tunnel routing config (NOT sensitive)
└── deployment.yaml         # 2-replica Deployment, spread across nodes

external-secrets-configs/cloudflared/
└── external-secret.yaml    # Pulls credentials.json from Vault

argocd/applications/
└── cloudflared-app.yaml    # ArgoCD Application
```

### How Credentials Mount in the Pod

```yaml
volumeMounts:
  - name: config
    mountPath: /etc/cloudflared/config.yml
    subPath: config.yml        # single file mount from ConfigMap
  - name: creds
    mountPath: /etc/cloudflared/creds   # directory mount from Secret
```

Resulting filesystem inside the container:
```
/etc/cloudflared/config.yml              ← from ConfigMap
/etc/cloudflared/creds/credentials.json  ← from Secret (via Vault/ESO)
```

The ConfigMap's `credentials-file` field points at `/etc/cloudflared/creds/credentials.json` — matching where the Secret volume mounts it.

### Vault Secret Path

```
secret/cloudflared/tunnel
  └── credentials.json   # full JSON content of the original
                          # /etc/cloudflared/<tunnel-id>.json file
```

### Migration Process (Zero-Downtime)

The key insight: Cloudflare Tunnels support multiple concurrent connectors on one tunnel. The new pods come up as **additional** connectors alongside the old systemd instance, and the old path is only removed after the new one is proven healthy.

**1. Store Tunnel Credentials in Vault**
```bash
# Extract credentials from the node running systemd cloudflared
# File location: /etc/cloudflared/<tunnel-id>.json or ~/.cloudflared/<tunnel-id>.json

# Load into Vault
kubectl exec -n vault vault-0 -- vault kv put secret/cloudflared/tunnel \
  credentials.json=@/tmp/credentials.json
```

**2. Create Manifests**
```bash
# Namespace, ConfigMap, Deployment
kubectl apply -f cloudflared/namespace.yaml
kubectl apply -f cloudflared/configmap.yaml
kubectl apply -f cloudflared/deployment.yaml

# ExternalSecret (requires namespace to exist first)
kubectl apply -f external-secrets-configs/cloudflared/external-secret.yaml
```

**3. Deploy via ArgoCD**
```bash
kubectl apply -f argocd/applications/cloudflared-app.yaml
```

**4. Verify New Pods Are Running**
```bash
kubectl get pods -n cloudflared -o wide
kubectl logs -n cloudflared -l app=cloudflared --tail=50
```

At this point, the Cloudflare Zero Trust dashboard should show additional connectors (new pods + still-running systemd) — both old and new paths are active simultaneously.

**5. Cut Over — Stop the Old Service**
```bash
# Only after confirming the in-cluster pods are healthy
sudo systemctl stop cloudflared
sudo systemctl disable cloudflared
```

**6. Verify**
```bash
curl -I https://yourdomain.com
curl -I https://argocd.yourdomain.com
```

Expected: `HTTP/2 200` — served entirely by in-cluster pods.

## Results

**Pod Distribution:**
```
NAME                          READY   NODE     AGE
cloudflared-xxxxx-abc12       1/1     node01   5m
cloudflared-xxxxx-def34       1/1     node03   5m
```

**Key Metrics:**
- ✅ 2 replicas on different physical nodes
- ✅ Zero downtime during migration (old + new ran simultaneously)
- ✅ All public sites confirmed healthy after systemd service stopped
- ✅ Credentials managed by Vault + ESO (auto-refreshed hourly)
- ✅ Full GitOps management via ArgoCD (drift detection, self-heal)

## Sync Order Dependency

The `cloudflared` namespace must exist before the `external-secrets-config` ArgoCD Application (which recurses `external-secrets-configs/` with `recurse: true`) can create the ExternalSecret into it.

**Correct order when bootstrapping from scratch:**
1. Apply `cloudflared-app.yaml` first (creates namespace + ConfigMap + Deployment)
2. ArgoCD's `external-secrets-config` app auto-discovers the new `cloudflared/` folder and syncs the ExternalSecret
3. ESO creates the `cloudflared-credentials` Secret from Vault
4. Pods pick up the Secret and connect to Cloudflare

If the ExternalSecret fails with `namespaces "cloudflared" not found`, manually sync the cloudflared Application first, then re-sync external-secrets-config.

## Rollback

If the in-cluster pods fail and traffic needs to fall back immediately:

```bash
sudo systemctl start cloudflared
sudo systemctl status cloudflared   # confirm active/running
```

The old config and credentials file at `/etc/cloudflared/` on the original node should be left in place (not deleted) to keep this rollback option available. Safe to remove only after running stable in-cluster for an extended period.

## Troubleshooting

### Pods Running but No Tunnel Connection
```bash
# Check logs for authentication errors
kubectl logs -n cloudflared -l app=cloudflared --tail=50

# Verify the Secret was created by ESO
kubectl get secret cloudflared-credentials -n cloudflared

# Verify ExternalSecret status
kubectl get externalsecret -n cloudflared
```

### Both Pods Scheduled on Same Node
```bash
# topologySpreadConstraints should prevent this
# Check if constraint is present in the Deployment
kubectl get deployment cloudflared -n cloudflared -o yaml | grep -A 10 topologySpread

# Check available nodes (need at least 2 schedulable)
kubectl get nodes
```

## Lessons Learned

1. **Your tunnel is a SPOF you forgot about.** Everything behind it — every public hostname, every external-facing service — goes dark when one systemd process on one machine stops. This is easy to overlook because the tunnel "just works" until it doesn't.
2. **Zero-downtime migration is built in.** Cloudflare Tunnels natively support multiple connectors per tunnel ID. Run old and new simultaneously, verify, then cut over — no risk window.
3. **Sync ordering matters in GitOps.** When an ExternalSecret targets a namespace created by a different ArgoCD Application, the namespace must exist first. Document these dependencies explicitly.
4. **Credentials format matters.** Cloudflared uses a JSON credentials file (not a token). Both the JSON file and the `config.yml` referencing it are required — missing either one and the tunnel won't authenticate.
5. **ConfigMap vs. Secret separation.** Tunnel ID and routing rules are not sensitive — commit them freely. Only the credentials JSON needs protection. Over-securing non-sensitive config adds complexity without security benefit.

## Future Enhancements

- [ ] Add resource requests/limits to the Deployment
- [ ] Add PodDisruptionBudget to prevent both replicas being evicted simultaneously
- [ ] Pin cloudflared image to a specific version (currently `latest`)
- [ ] Remove `/etc/cloudflared/` from original node after extended stable period

---

**Migration Date:** July 3, 2026
**Cluster:** 4-node bare-metal Kubernetes (Ubuntu 24.04, k8s v1.35.0)
