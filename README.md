# k8s-play-ground

A local Kubernetes playground built on **Colima + K3s**, managed via **Argo CD GitOps**.

## Stack

| Component | Purpose |
|-----------|---------|
| Colima + K3s | Local single-node cluster |
| Traefik | Ingress + Gateway API controller |
| Headlamp | Kubernetes Web UI |
| VictoriaMetrics + VictoriaLogs + Grafana | Observability |
| Kyverno | Policy enforcement |
| cert-manager | TLS automation |
| Argo CD | GitOps continuous delivery |

## Repository Layout

```
.
├── apps/                      # Application definitions
│   ├── cluster-policies/      # Kyverno, PSA, NetworkPolicies
│   ├── headlamp/              # Headlamp UI Helm values
│   ├── observability/         # VictoriaMetrics/Grafana stack
│   └── web-filesystem/        # Sample workload
├── argocd/                    # Argo CD Application manifests
├── LOCAL_K8S_SETUP.md         # Manual local cluster setup guide
├── AGENTS.md                  # Agent context for this repo
└── CLAUDE.md                  # Claude Code instructions
```

## Quick Start

1. **Start Colima cluster**
   ```bash
   colima start --cpu 4 --memory 8 --kubernetes --network-address
   ```

2. **Install Argo CD**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Apply the root App of Apps**
   ```bash
   kubectl apply -f argocd/root-app.yaml
   ```

4. **Access Argo CD UI**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Login: admin / $(argocd admin initial-password -n argocd)
   ```

## GitOps Workflow

All applications are deployed through Argo CD:
- `argocd/root-app.yaml` — Root "App of Apps"
- `argocd/apps/*.yaml` — Individual Argo CD Applications
- Changes merged to `main` are automatically synced to the cluster

## Local Development

See [LOCAL_K8S_SETUP.md](LOCAL_K8S_SETUP.md) for detailed manual setup instructions.

## Security

- Pod Security Admission enforced
- NetworkPolicies default-deny
- Kyverno policies for best practices
- No secrets committed to Git (see `.gitignore`)

## License

MIT
