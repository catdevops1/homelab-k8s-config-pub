# Installation Guide

## Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured
- Kustomize (included in kubectl 1.14+)

## Method 1: Direct kubectl
```bash
# Clone the repo
git clone https://github.com/catdevops1/homelab-k8s-config-pub.git
cd homelab-k8s-config-pub

# Deploy with default settings
kubectl apply -k descheduler/base/

# Or deploy an example
kubectl apply -k descheduler/examples/aggressive/
```

## Method 2: ArgoCD (GitOps)
```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: descheduler
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/catdevops1/homelab-k8s-config-pub.git
    targetRevision: main
    path: descheduler/examples/aggressive
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
```bash
kubectl apply -f argocd-app.yaml
```

## Method 3: Helm (using Kustomize)
```bash
# Install kustomize
kubectl kustomize descheduler/base/ | kubectl apply -f -
```

## Verification
```bash
# Check deployment
kubectl get cronjob -n kube-system descheduler

# Watch it run
kubectl get jobs -n kube-system -l app=descheduler

# View logs
kubectl logs -n kube-system -l app=descheduler --tail=50
```

## Customization

Create your own overlay:
```bash
mkdir -p my-config
cat > my-config/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- github.com/catdevops1/homelab-k8s-config-pub/descheduler/base

patchesStrategicMerge:
- configmap-patch.yaml
YAML
```

## Uninstall
```bash
kubectl delete -k descheduler/base/
```
