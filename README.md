# Homelab Kubernetes Infrastructure (Public) ⎈

Reusable, production-tested Kubernetes infrastructure components for bare-metal homelab clusters.

## Stack

| Component | Version |
|-----------|---------|
| Kubernetes | v1.35.0 |
| Envoy Gateway | v1.5.9 |
| Gateway API | v1.4.0 |
| Longhorn | v1.10.1 |
| OS | Ubuntu 24.04 LTS |
| Container Runtime | containerd |

---

## Infrastructure Components

### Gateway API with Envoy Gateway
- Migrated from ingress-nginx to Kubernetes Gateway API
- Envoy Gateway as the Gateway API implementation
- MetalLB for bare-metal LoadBalancer support
- cert-manager + Let's Encrypt for automated TLS
- Cloudflare Tunnel for external access with zero exposed ports
- See `gateway-api/README.md` for full migration guide

### Longhorn Distributed Storage
- 3-way replication across nodes for high availability
- Automatic failover for persistent volumes
- GitOps deployment via ArgoCD
- Zero single points of failure for stateful applications
- See `docs/longhorn-migration.md` for implementation details

### Cloudflare Tunnel (In-Cluster)
- Migrated from systemd service on a single node to 2-replica Kubernetes Deployment
- `topologySpreadConstraints` ensure replicas run on different physical nodes
- Credentials managed by HashiCorp Vault + External Secrets Operator
- Zero-downtime migration using Cloudflare's multi-connector support
- See `docs/cloudflared-migration.md` for the full migration walkthrough

### Descheduler
- Automatic pod rebalancing across nodes
- Optimizes cluster resource utilization
- Handles node recovery after failures
- Three profiles: aggressive, basic, conservative

### Secrets Management
For HashiCorp Vault + External Secrets Operator + AWS KMS auto-unseal, see the dedicated repo:
[`vault-config-pub`](https://github.com/catdevops1/vault-config-pub)

An example ExternalSecret for wiring an app to Vault is in `external-secrets-configs/cluster-ai/`.

---

## Repository Structure

```
├── argocd/
│   └── applications/              # ArgoCD Application manifests
│       ├── cloudflared-app.yaml
│       ├── envoy-gateway-app.yaml
│       ├── gateway-config-app.yaml
│       ├── descheduler-app.yaml
│       └── longhorn-app.yaml
├── cloudflared/                   # In-cluster Cloudflare Tunnel
│   ├── namespace.yaml
│   ├── configmap.yaml
│   └── deployment.yaml
├── descheduler/
│   ├── base/                      # Base Kustomize resources
│   └── examples/                  # aggressive / basic / conservative profiles
├── docs/                          # Migration guides and use cases
├── external-secrets-configs/
│   ├── cloudflared/               # Tunnel credentials via Vault
│   └── cluster-ai/               # Example ExternalSecret for app secrets
├── gateway-api/
│   ├── gateway/                   # GatewayClass, Gateway, TLS, ClusterIssuer
│   └── routes/example/            # Example HTTPRoute template
├── longhorn/
│   └── overlays/production/
└── scripts/                       # Utility and test scripts
```

---

## Quick Start

### Deploy Gateway API (Envoy Gateway)
```bash
# 1. Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# 2. Deploy Envoy Gateway via ArgoCD
kubectl apply -f argocd/applications/envoy-gateway-app.yaml

# 3. Deploy Gateway config (GatewayClass, Gateway, TLS)
kubectl apply -f argocd/applications/gateway-config-app.yaml
```

### Deploy Longhorn (Distributed Storage)
```bash
kubectl apply -f argocd/applications/longhorn-app.yaml
```

### Deploy Cloudflare Tunnel (In-Cluster)
```bash
# 1. Store tunnel credentials in Vault (see docs/cloudflared-migration.md)
# 2. Deploy via ArgoCD
kubectl apply -f argocd/applications/cloudflared-app.yaml
```

### Deploy Descheduler
```bash
# Choose a profile
kubectl apply -k descheduler/examples/aggressive/   # fast rebalancing
kubectl apply -k descheduler/examples/basic/        # default
kubectl apply -k descheduler/examples/conservative/ # minimal disruption
```

---

## Cluster Details

- **Environment:** Bare-metal Kubernetes (no hypervisor)
- **OS:** Ubuntu 24.04 LTS
- **Networking:** MetalLB + Cloudflare Tunnel (no exposed ports)

---

## Key Features

- **GitOps Workflow** — All infrastructure as code, managed via ArgoCD
- **Modern Ingress** — Gateway API replaces legacy Ingress — native traffic splitting, header manipulation, multi-protocol
- **Resilient Tunnel** — Multi-replica cloudflared with topology-aware scheduling, no single node dependency
- **High Availability** — Longhorn 3-way replication eliminates storage single points of failure
- **Automated Operations** — Descheduler handles pod rebalancing after node failures
- **Zero Trust Networking** — Cloudflare Tunnel, no inbound firewall rules required
- **Production-Grade** — Running real applications with CI/CD pipelines

---

## Documentation

- `gateway-api/README.md` — ingress-nginx → Envoy Gateway migration guide
- `docs/cloudflared-migration.md` — systemd → in-cluster tunnel migration
- `docs/longhorn-migration.md` — hostPath → distributed storage walkthrough
- `docs/use-cases.md` — descheduler configuration scenarios
- `docs/installation.md` — getting started guide

---

## Related Repos

- [`vault-config-pub`](https://github.com/catdevops1/vault-config-pub) — HashiCorp Vault + External Secrets Operator + AWS KMS auto-unseal
- [`cluster-ai`](https://github.com/catdevops1/cluster-ai) — Natural language Kubernetes assistant (FastAPI + React + Ollama + Claude)

---

*Last Updated: July 2026*
