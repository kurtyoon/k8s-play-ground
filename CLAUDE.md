# Claude Code Instructions

## Project

This is a **local Kubernetes playground** using Colima + K3s, managed via **Argo CD GitOps**.

## Context

- Single-node cluster (Colima VM)
- Traefik as Ingress + Gateway controller
- Applications deployed from `apps/` via Argo CD
- Domains resolved via `/etc/hosts` pointing to `127.0.0.1`

## Rules

1. **Never commit secrets.** `.envrc`, `*.env`, `*.key`, `*.pem` are in `.gitignore`.
2. **Never commit agent files.** `.sisyphus/`, `.omx/` are ignored.
3. **Follow security conventions.** All namespaces need PSA labels, NetworkPolicies, LimitRanges, ResourceQuotas.
4. **Use non-root containers.** `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `drop: [ALL]`.
5. **No `latest` tags.** Pin all image tags explicitly.
6. **Label everything.** `app.kubernetes.io/name` and `app.kubernetes.io/part-of` are required.
7. **GitOps first.** New apps should be added as Argo CD Applications in `argocd/apps/`.

## Preferred Patterns

- Kubernetes manifests: plain YAML or Kustomize
- App packaging: Helm values files + install scripts
- Observability: VictoriaMetrics + VictoriaLogs + Grafana
- Policies: Kyverno + Pod Security Admission
- GitOps: Argo CD Application / App of Apps pattern

## Common Tasks

- Add app → create `apps/<app>/`, add `argocd/apps/<app>.yaml`, apply root-app
- Update app → edit manifests, commit, Argo CD auto-syncs
- Troubleshoot → check NetworkPolicies, check Traefik egress, verify DNS policies

## References

- `LOCAL_K8S_SETUP.md` — Detailed setup, architecture, and troubleshooting
- `AGENTS.md` — Agent context and conventions
- `argocd/` — GitOps manifests
