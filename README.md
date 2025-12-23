# Homelab Kubernetes Infrastructure (Public)
Reusable, production-tested Kubernetes infrastructure components for bare-metal homelab clusters.

## Infrastructure Components

### Longhorn Distributed Storage
- **3-way replication** across nodes for high availability
- **Automatic failover** for persistent volumes
- **GitOps deployment** via ArgoCD
- Zero single points of failure for stateful applications
- See [docs/longhorn-migration.md](docs/longhorn-migration.md) for implementation details

### Descheduler
- Automatic pod rebalancing across nodes
- Optimizes cluster resource utilization
- Handles node maintenance scenarios

### Node Labels
- Organize nodes by reliability and workload type
- Supports UPS-backed vs non-UPS nodes
- Custom scheduling policies

## Repository Structure
```
├── argocd/
│   └── applications/          # ArgoCD Application manifests
│       ├── descheduler-app.yaml
│       └── longhorn-app.yaml
├── descheduler/
│   └── overlays/production/   # Descheduler configuration
├── longhorn/
│   └── overlays/production/   # Longhorn distributed storage
├── node-labels/               # Node labeling scripts
├── docs/                      # Documentation
│   └── longhorn-migration.md  # Storage migration guide
└── scripts/                   # Utility scripts
```

## Quick Start

### Deploy Longhorn (Distributed Storage)
```bash
kubectl apply -f argocd/applications/longhorn-app.yaml
```

### Deploy Descheduler
```bash
kubectl apply -f argocd/applications/descheduler-app.yaml
```

### Apply Node Labels
```bash
./node-labels/apply-labels.sh
```

## Cluster Details

**Environment:** Bare-metal Kubernetes  
**OS:** Ubuntu 24.04 LTS  
**Kubernetes:** v1.33.3  
**Container Runtime:** containerd  
**Nodes:** 4-node cluster (1 control-plane, 3 workers)

## Production Applications

This infrastructure supports multiple production applications including:
- Business management platforms
- Asset tracking systems
- Invoice and billing applications
- Internal tools and dashboards
## Key Features

- **High Availability:** Longhorn 3-way replication eliminates single points of failure
- **GitOps Workflow:** All infrastructure as code, managed via ArgoCD
- **Automated Operations:** Descheduler handles pod rebalancing automatically
- **Production-Grade:** Running real business applications with zero downtime SLA

## Documentation

- [Longhorn Migration Guide](docs/longhorn-migration.md) - Complete walkthrough of migrating from hostPath to distributed storage

## Future Roadmap

- [ ] Longhorn backup configuration (S3/NFS)
- [ ] Prometheus & Grafana monitoring stack
- [ ] Cert-manager automation
- [ ] MetalLB load balancer configuration
- [ ] NGINX Ingress controller docs


  
**Last Updated:** December 22, 2025
