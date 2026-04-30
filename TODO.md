# Cluster Maturity TODO

> Remaining work to mature the k8s-play-ground cluster after Keycloak + OpenBao deployment.
> Last updated: 2026-04-30

## Completed

- [x] Deploy Keycloak (codecentric/keycloakx) with standalone PostgreSQL
- [x] Deploy OpenBao (Raft storage, persistent) and initialize/unseal
- [x] Deploy External Secrets Operator (ESO) and fix CRD annotation size issue
- [x] Configure ClusterSecretStore for OpenBao + verify secret sync
- [x] Create Keycloak realm `k8s-playground` with OIDC clients (argocd, headlamp, grafana)
- [x] Configure ArgoCD, Grafana, Headlamp for Keycloak OIDC
- [x] Fix web-filesystem OutOfSync (latest tag + PSA hostPath issue)
- [x] All ArgoCD apps Synced Healthy

## Remaining

### 1. Harden Keycloak Admin Credentials
**Priority**: High

Current `apps/keycloak/values.yaml` hardcodes:
```yaml
KEYCLOAK_ADMIN: admin
KEYCLOAK_ADMIN_PASSWORD: admin
```

**Action**:
- Create Kubernetes Secret `keycloak-admin` in `iam` namespace
- Update `values.yaml` to reference the secret via `envFrom` or `extraEnvFrom`
- Document rotation procedure

**Files**:
- `apps/keycloak/admin-secret.yaml` (new)
- `apps/keycloak/values.yaml` (update)

---

### 2. Add ResourceQuota and LimitRange to `iam` and `vault` Namespaces
**Priority**: High

Other namespaces (headlamp, observability, web-filesystem) already have ResourceQuota and LimitRange. `iam` and `vault` are missing both.

**Action**:
- Create `apps/cluster-policies/default-resourcequota.yaml` or per-namespace manifests
- Add ResourceQuota for pods, CPU, memory, services, PVCs
- Add LimitRange with default/min/max CPU and memory requests/limits

**Files**:
- `apps/cluster-policies/iam-resourcequota.yaml` (new)
- `apps/cluster-policies/vault-resourcequota.yaml` (new)
- `apps/cluster-policies/iam-limitrange.yaml` (new)
- `apps/cluster-policies/vault-limitrange.yaml` (new)
- `argocd/apps/cluster-policies.yaml` (add paths if needed)

---

### 3. Add ArgoCD Ingress
**Priority**: Medium

Currently ArgoCD is only accessible via `kubectl port-forward`. Add ingress for `argocd.local`.

**Action**:
- Create `apps/argocd/ingress.yaml` (or add to existing argocd manifests)
- Configure Traefik ingress with `web` entrypoint
- Update `/etc/hosts` with `argocd.local`
- Verify Keycloak OIDC login works through ingress URL

**Files**:
- `apps/argocd/ingress.yaml` (new)
- `LOCAL_K8S_SETUP.md` (update access instructions)

---

### 4. Verify End-to-End OIDC Login Flow
**Priority**: High

OIDC config is in place but not yet manually tested through the browser.

**Action**:
1. Access `http://argocd.local` (or port-forward) → click "Login via Keycloak"
2. Access `http://grafana.local` → "Sign in with Keycloak"
3. Access `http://headlamp.local` → OIDC login
4. Login with `testuser` / `testpassword`
5. Verify group mapping (`argocd-admin` → Admin role)

**Troubleshooting**:
- If Keycloak hostname mismatch: check `KC_HOSTNAME` and ingress host alignment
- If redirect URI error: update Keycloak client redirectUris
- If certificate error: disable TLS verification for local playground

---

### 5. OpenBao Secret Rotation / Backup
**Priority**: Medium

OpenBao unseal key and root token are currently only documented in session notes.

**Action**:
- Store unseal key and root token in a secure location (1Password, local vault, etc.)
- Consider periodic snapshots: `bao operator raft snapshot save`
- Document disaster recovery steps

---

### 6. ESO Production Hardening
**Priority**: Medium

Current ESO test ExternalSecret (`test-openbao-secret`) should be removed or moved to a dedicated test namespace.

**Action**:
- Remove `apps/external-secrets/test-externalsecret.yaml` or move to `apps/external-secrets/tests/`
- Add `ClusterExternalSecret` or namespace-scoped `ExternalSecret` for real workloads
- Consider adding `refreshInterval` tuning and secret caching

---

## Notes

- `/etc/hosts` needs: `127.0.0.1 keycloak.local openbao.local argocd.local`
- ArgoCD admin password can be retrieved via: `argocd admin initial-password -n argocd`
- Keycloak admin CLI (`kcadm.sh`) requires `JAVA_HOME` to be set inside the pod
- OpenBao must remain unsealed after pod restarts (auto-unseal not configured in this local setup)
