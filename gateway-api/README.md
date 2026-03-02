# Kubernetes Gateway API with Envoy Gateway

Migration from ingress-nginx to Envoy Gateway using Kubernetes Gateway API on bare-metal.

## Stack
- Kubernetes v1.35.0
- Gateway API v1.4.0 (CRDs)
- Envoy Gateway v1.5.9
- MetalLB (bare-metal LoadBalancer)
- cert-manager + Let's Encrypt (TLS)
- Cloudflare Tunnel (external access, no open ports)

## Architecture
```
Internet → Cloudflare → Cloudflare Tunnel → MetalLB IP → Envoy Gateway → App Pods
```

## Why Gateway API over Ingress?

| Feature | Ingress | Gateway API |
|---|---|---|
| Traffic splitting | Annotation-based | Native |
| Header manipulation | Annotation-based | Native |
| Multi-protocol | HTTP only | HTTP, TCP, UDP, gRPC |
| Role separation | None | GatewayClass/Gateway/Route |
| Future support | Maintenance mode | Active development |

## Installation

### 1. Install Gateway API CRDs
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

### 2. Install Envoy Gateway via ArgoCD
```bash
kubectl apply -f argocd/applications/envoy-gateway-app.yaml
```

### 3. Create GatewayClass and Gateway
```bash
kubectl apply -f gateway-api/gateway/gatewayclass.yaml
kubectl apply -f gateway-api/gateway/gateway.yaml
```

### 4. Create HTTPRoutes per app
```bash
kubectl apply -f gateway-api/routes/example/httproute.yaml
```

## Migration Status
- [x] CRDs installed
- [x] Envoy Gateway installed
- [x] GatewayClass + Gateway created
- [x] All applications migrated
- [x] ingress-nginx removed
