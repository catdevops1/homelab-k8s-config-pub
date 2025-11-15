# Descheduler Use Cases

## Scenario 1: Homelab with Intermittent Power

**Problem**: One node loses power frequently (no UPS), causing pods to pile up on other nodes.

**Solution**: Use `aggressive` configuration
```bash
kubectl apply -k descheduler/examples/aggressive/
```

**How it works**:
1. Node goes offline
2. Pods reschedule to remaining nodes
3. Node comes back online (sits idle)
4. Descheduler runs every 5 minutes
5. Pods automatically move to the idle node

**Node labeling**:
```bash
kubectl label nodes stable-node power-reliability=ups-backed availability=high
kubectl label nodes unstable-node power-reliability=intermittent availability=low
```

## Scenario 2: Mixed Hardware Cluster

**Problem**: Different node specs (powerful server + old laptops), want to use all efficiently.

**Solution**: Use `basic` configuration + node labels
```bash
kubectl apply -k descheduler/examples/basic/

# Label by capability
kubectl label nodes powerful-server workload-type=heavy-compute
kubectl label nodes laptop-1 workload-type=light-tasks
kubectl label nodes laptop-2 workload-type=light-tasks
```

## Scenario 3: Development Cluster

**Problem**: Frequently testing, deploying, scaling. Want stability over perfect balance.

**Solution**: Use `conservative` configuration
```bash
kubectl apply -k descheduler/examples/conservative/
```

Runs every 30 minutes, only rebalances when seriously imbalanced.

## Scenario 4: Multi-Zone Homelab

**Problem**: Nodes in different rooms/locations, want to spread for redundancy.

**Solution**: Use topology spread constraints + descheduler
```yaml
# Add to deployments
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: ScheduleAnyway
```

Label nodes:
```bash
kubectl label nodes bedroom-pi topology.kubernetes.io/zone=bedroom
kubectl label nodes garage-server topology.kubernetes.io/zone=garage
```

## Resource Requests Are Required!

⚠️ **Important**: Descheduler uses resource **requests** to calculate utilization, not actual usage.

Your pods MUST have resource requests defined:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "200m"
```

Without requests, descheduler sees 0% utilization and won't rebalance!
