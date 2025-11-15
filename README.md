# Homelab Kubernetes Configuration (Public)

Reusable Kubernetes configurations for homelab clusters. Production-tested templates for:

- **Descheduler**: Automatic pod rebalancing across nodes
- **Node Labels**: Organize nodes by reliability and workload type
- **GitOps Ready**: Kustomize-based with ArgoCD examples

## Perfect For

- Homelabs with intermittent power (UPS on some nodes, not others)
- Multi-node clusters with different hardware specs
- Learning Kubernetes best practices
- Bare-metal clusters

## Quick Start
```bash
# Deploy descheduler with default settings
kubectl apply -k descheduler/base/

# Or use a pre-configured example
kubectl apply -k descheduler/examples/aggressive/
```

## What's Inside

- `/descheduler/base/` - Core descheduler manifests
- `/descheduler/examples/` - Pre-configured scenarios
- `/scripts/` - Utility scripts for node management
- `/docs/` - Detailed guides and explanations

## Use Cases

See [docs/use-cases.md](docs/use-cases.md) for detailed scenarios.

## License

MIT - Use freely in your homelab!
