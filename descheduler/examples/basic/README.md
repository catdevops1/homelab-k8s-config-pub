# Basic Descheduler Configuration

Default configuration suitable for most stable homelab clusters.

- **Thresholds**: 30% (rebalance if node < 30% utilized)
- **Targets**: 60% (nodes above this are considered overloaded)
- **Schedule**: Every 10 minutes

## Deploy
```bash
kubectl apply -k .
```

## Use Case

Stable homelab with reliable power and similar hardware across all nodes.
