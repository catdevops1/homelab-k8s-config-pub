# Conservative Descheduler Configuration

Minimal rebalancing - only when nodes are heavily imbalanced.

- **Thresholds**: 40% 
- **Targets**: 70% (only triggers on significant imbalance)
- **Schedule**: Every 30 minutes

## Deploy
```bash
kubectl apply -k .
```

## Use Case

Production-like homelabs where stability is more important than perfect balance.
