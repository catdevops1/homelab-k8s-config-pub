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

## Directory Structure
```
gateway-api/
├── gateway/
│   ├── gatewayclass.yaml          # Binds Envoy Gateway controller
│   ├── gateway.yaml               # Main gateway, HTTP + HTTPS listeners
│   ├── cluster-issuer.yaml        # cert-manager ClusterIssuer (Let's Encrypt)
│   └── main-tls-certificate.yaml  # Wildcard/multi-domain TLS certificate
└── routes/
    └── example/
        └── httproute.yaml         # Example HTTPRoute template per app
```

## Installation

### 1. Install Gateway API CRDs
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

### 2. Install Envoy Gateway via ArgoCD
```bash
kubectl apply -f argocd/applications/envoy-gateway-app.yaml
```

### 3. Deploy Gateway config via ArgoCD
```bash
kubectl apply -f argocd/applications/gateway-config-app.yaml
```

Or apply manually:
```bash
kubectl apply -f gateway-api/gateway/gatewayclass.yaml
kubectl apply -f gateway-api/gateway/cluster-issuer.yaml
kubectl apply -f gateway-api/gateway/gateway.yaml
kubectl apply -f gateway-api/gateway/main-tls-certificate.yaml
```

### 4. Create HTTPRoutes per app
```bash
# Copy the example and customize for each application
cp gateway-api/routes/example/httproute.yaml gateway-api/routes/my-app/httproute.yaml
kubectl apply -f gateway-api/routes/my-app/httproute.yaml
```

## Configuration

Before applying, replace placeholders in the gateway files:

| File | Placeholder | Replace With |
|---|---|---|
| `gateway.yaml` | `<YOUR-METALLB-IP>` | IP from your MetalLB pool |
| `cluster-issuer.yaml` | `<YOUR-EMAIL>` | Email for Let's Encrypt notifications |
| `main-tls-certificate.yaml` | `your-domain.com` | Your actual domain(s) |
| `argocd/applications/gateway-config-app.yaml` | `<YOUR-USERNAME>/<YOUR-REPO>` | Your GitHub repo |

## Migration Status
- [x] CRDs installed
- [x] Envoy Gateway installed
- [x] GatewayClass + Gateway created
- [x] cert-manager ClusterIssuer configured
- [x] TLS certificate issued
- [x] All applications migrated to HTTPRoutes
- [x] ingress-nginx removed
