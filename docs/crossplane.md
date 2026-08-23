# Crossplane — Cloudflare as Code

## Why this exists

I got tired of making DNS changes in the Cloudflare dashboard by hand.
One wrong click and a record is gone, no history, no rollback, no audit trail.

Crossplane fixes that. Every DNS record, every Zero Trust Access rule lives
in Git. Argo CD syncs it. If someone changes something in the dashboard,
Crossplane reverts it automatically.

## What it manages

- DNS records for catdevops.net
- Drift detection and auto-repair

## Planned

- Cloudflare Zero Trust Access managed as code

## Stack

- Crossplane v2.3.2
- provider-cloudflare-dns v0.1.3 (wildbitca)
- External Secrets Operator — pulls Cloudflare API token from Vault
- Argo CD — syncs everything from this repo

## How credentials work

The Cloudflare API token never touches Git.
It lives in Vault and gets injected into the cluster via External Secrets:

```
Vault → ExternalSecret → Kubernetes Secret → Crossplane ProviderConfig
```

Token permissions needed:
- Zone → DNS → Edit
- Zone → Zone → Read
- Account → Access: Apps and Policies → Edit

## Setup

Store the token in Vault:
```bash
vault kv put secret/cloudflare/credentials \
  credentials='{"api_token":"YOUR_TOKEN"}'
```

Apply the Argo CD apps:
```bash
kubectl apply -f argocd/applications/crossplane-helm-app.yaml
kubectl apply -f argocd/applications/crossplane-config-app.yaml
```

Verify:
```bash
kubectl get providers
kubectl get providerconfig -A
```

## Cluster

5-node bare-metal kubeadm cluster.
Everything from DNS to deployments managed through GitOps.
No cloud provider. No managed Kubernetes. Just Linux and YAML.
