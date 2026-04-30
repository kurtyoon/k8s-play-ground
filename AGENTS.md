# Agent Context: k8s-play-ground

## Project Identity

**Name:** k8s-play-ground  
**Type:** Local Kubernetes playground / GitOps demo  
**Cluster:** Colima + K3s (single-node)  
**GitOps:** Argo CD

## Architecture

- **Orchestration:** K3s (v1.35.0+) with Flannel CNI
- **Ingress/Gateway:** Traefik (K3s built-in, upgraded via Helm) + Gateway API v1.2.0
- **Ingress Entry:** `kubectl port-forward` via localhost + `/etc/hosts`
- **Domains:** `*.local` (headlamp.local, grafana.local, web-filesystem.local)

## Application Map

| App | Namespace | Access | Type |
|-----|-----------|--------|------|
| headlamp | headlamp | http://headlamp.local | Helm (via script) |
| web-filesystem | web-filesystem | http://web-filesystem.local | Kustomize |
| observability | observability | http://grafana.local | Helm scripts |
| cluster-policies | various | — | Raw YAML |

## Key Files

- `LOCAL_K8S_SETUP.md` — Full manual setup & troubleshooting
- `argocd/` — Argo CD GitOps manifests
- `apps/` — Per-app Kubernetes manifests and Helm values

## Conventions

- All namespaces have: PSA labels, LimitRange, ResourceQuota, NetworkPolicy
- All pods run as non-root with read-only root filesystem
- No `latest` image tags
- Every workload has `app.kubernetes.io/name` and `app.kubernetes.io/part-of` labels
- Secrets and `.envrc` are **never committed**

## Common Commands

```bash
# Cluster status
kubectl get nodes -o wide
kubectl get pods -A

# Traefik / Gateway
kubectl get gateway,httproute,ingress -A

# Port-forward for local access
kubectl -n kube-system port-forward --address=127.0.0.1 svc/traefik 80:80

# Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Troubleshooting References

- 502 errors → Check NetworkPolicies (Traefik egress, app ingress)
- Grafana no data → Check `allow-observability-internal` NetworkPolicy
- DNS failures → Verify `allow-dns-ingress` in kube-system
- Port conflicts → Check for Docker containers squatting on port 80

## GitHub Repository

https://github.com/kurtyoon/k8s-play-ground
