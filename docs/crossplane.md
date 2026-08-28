# Crossplane — Cloudflare as Code

## Why this exists

I got tired of making DNS changes in the Cloudflare dashboard by hand.
One wrong click and a record is gone, no history, no rollback, no audit trail.

Crossplane fixes that. Every DNS record lives in Git. Argo CD syncs it.
If someone changes a record in the dashboard, Crossplane reverts it automatically.

## What it manages

- DNS records for catdevops.net — tunnel CNAMEs, MX, DKIM, SPF, DMARC
- Continuous drift detection and auto-repair
- Existing records adopted in place, not recreated

## Planned

- Cloudflare Zero Trust Access managed as code via `provider-cloudflare-access`

## Stack

- Crossplane v2.3.2
- provider-cloudflare-dns v0.1.3 (wildbitca)
- External Secrets Operator — pulls the Cloudflare API token from Vault
- Argo CD — syncs everything from Git

## How credentials work

The Cloudflare API token never touches Git. It lives in Vault and is injected
into the cluster by External Secrets:

```
Vault → ExternalSecret → Kubernetes Secret → Crossplane ProviderConfig
```

The provider expects the credential as a JSON object, not a plain string:

```json
{ "api_token": "..." }
```

Token permissions needed:

- Zone → DNS → Edit
- Zone → Zone → Read
- Account → Access: Apps and Policies → Edit (for the planned Access work)

## Three-app structure

Splitting this into three Argo CD applications enforces ordering and avoids
resource-tracking problems:

```
crossplane              → Crossplane core (Helm chart)
crossplane-cloudflare   → providers/ — Provider + ProviderConfig
crossplane-dns          → cloudflare/ — DNS records
```

Each depends on the previous one being healthy. A single app pointing at the
repo root does not work reliably — Argo CD applies the ProviderConfig before
its CRD exists, and changing an app's `path` later causes it to lose track of
resources it already manages and prune them.

## Required Argo CD configuration

Crossplane needs annotation-based resource tracking:

```bash
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"application.resourceTrackingMethod":"annotation"}}'
```

Argo CD reads this at startup, so restart all three components afterwards:

```bash
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
```

The Provider and ProviderConfig also need these sync options:

```yaml
syncOptions:
  - ServerSideApply=true              # provider CRDs exceed the annotation size limit
  - SkipDryRunOnMissingResource=true  # ProviderConfig CRD does not exist until the provider installs
```

## Adopting existing records

Existing Cloudflare records are adopted rather than recreated, so there is no
DNS gap. Fetch the real record IDs first:

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.result[] | {id, name, type, content, proxied}'
```

Then reference each ID in the manifest:

```yaml
metadata:
  annotations:
    crossplane.io/external-name: "<existing record id>"
```

Crossplane looks up that ID, finds the existing record, and takes ownership
without creating a duplicate. Verify with `SYNCED: True` and `READY: True`,
then confirm the record count in Cloudflare has not changed.

## Protecting email records

Email records must never be modified by accident. Setting management policies
to `Observe` makes Crossplane watch them without ever writing or deleting:

```yaml
spec:
  managementPolicies:
    - Observe
```

Tunnel CNAMEs keep the default (`["*"]`) so drift correction stays active on
records that actually change.

## Recovering from stuck terminating records

If Argo CD prunes the Record objects, they enter a terminating state held by
the Crossplane finalizer. A `deletionTimestamp` cannot be removed, so the
objects have to finish dying — but the real Cloudflare records must survive.

Order matters. Back up first:

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $TOKEN" | jq '.result' > cf-dns-backup.json
```

Set every record to `Observe` so Crossplane cannot delete the external resource:

```bash
for r in $(kubectl get record.dns.upjet-cloudflare.m.upbound.io -n crossplane-system -o name); do
  kubectl patch $r -n crossplane-system --type merge \
    -p '{"spec":{"managementPolicies":["Observe"]}}'
done
```

Verify the policy actually applied before continuing. Only then clear the
finalizers:

```bash
for r in $(kubectl get record.dns.upjet-cloudflare.m.upbound.io -n crossplane-system -o name); do
  kubectl patch $r -n crossplane-system --type merge \
    -p '{"metadata":{"finalizers":null}}'
done
```

Argo CD recreates the objects from Git within seconds, and the
`external-name` annotations make Crossplane re-adopt the same records.

Clearing the finalizer before setting `Observe` deletes the real DNS records.

## Setup

Store the token in Vault:

```bash
vault kv put secret/cloudflare/credentials \
  credentials='{"api_token":"YOUR_TOKEN"}'
```

Apply the Argo CD apps in order, waiting for each to be healthy:

```bash
kubectl apply -f argocd/applications/crossplane-helm-app.yaml
kubectl apply -f argocd/applications/crossplane-config-app.yaml
kubectl apply -f argocd/applications/crossplane-dns-app.yaml
```

Verify:

```bash
kubectl get providers
kubectl get providerconfig -A
kubectl get record.dns.upjet-cloudflare.m.upbound.io -n crossplane-system
```

## Notes

- `managementPolicies` is a beta feature in this provider — the flag appears in
  the provider logs on startup. It is applied on create; patching it onto an
  existing object works, but do not assume the manifest value took effect
  without checking.
- Resource footprint is small: roughly 22m CPU and 208Mi memory across
  Crossplane core, the RBAC manager, and both providers.

## Cluster

5-node bare-metal kubeadm cluster.
Everything from DNS to deployments managed through GitOps.
No cloud provider. No managed Kubernetes. Just Linux and YAML.
