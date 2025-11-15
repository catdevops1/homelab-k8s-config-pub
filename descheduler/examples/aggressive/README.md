# Aggressive Descheduler Configuration

For homelabs with intermittent power or unstable nodes.

- **Thresholds**: 20% (very sensitive to imbalance)
- **Targets**: 50% (triggers at lower utilization)
- **Schedule**: Every 5 minutes (fast response)

## Deploy
```bash
kubectl apply -k .
```

## Use Case

Perfect for homelabs where:
- Some nodes lose power frequently
- You want pods to quickly redistribute when nodes come back online
- Hardware is diverse (some powerful, some weak nodes)

## Example Scenario

Node goes offline → Pods move to other nodes → Node comes back → Descheduler runs within 5 minutes → Pods rebalance automatically!
