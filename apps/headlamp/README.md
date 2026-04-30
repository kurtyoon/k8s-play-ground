# Headlamp - Kubernetes Web UI

> Declarative Helm-based deployment for [Headlamp](https://headlamp.dev/)
> Official Kubernetes SIG UI project

## Architecture

This directory follows an **Operator-style declarative management** pattern using Helm as the reconciliation engine.

```
values.yaml      <-- Desired state (declarative)
     |
     v
scripts/install.sh   --> helm upgrade --install (reconciliation)
```

### Why This Pattern?

Headlamp does not provide an official Kubernetes Operator (no CRD/Controller). The SIG UI team maintains only the Helm chart for in-cluster deployment.

This pattern treats Helm as a lightweight operator:
- **Declarative**: All configuration lives in `values.yaml`
- **Idempotent**: `install.sh` can be run repeatedly; Helm reconciles to desired state
- **GitOps-ready**: Easy to migrate to Flux `HelmRelease` or Argo CD `Application`

## Directory Layout

```
apps/headlamp/
├── values.yaml           # Base Helm values (desired state)
├── README.md             # This file
└── scripts/
    ├── install.sh        # Reconcile (install or upgrade)
    ├── uninstall.sh      # Remove release and optionally namespace
    └── port-forward.sh   # Local access via kubectl port-forward
```

## Quick Start

### Install / Upgrade

```bash
./apps/headlamp/scripts/install.sh
```

This command is idempotent — run it after any change to `values.yaml`.

### Access via Port Forward

```bash
./apps/headlamp/scripts/port-forward.sh
# Open http://127.0.0.1:8080
```

Or specify a custom local port:

```bash
./apps/headlamp/scripts/port-forward.sh 4466
# Open http://127.0.0.1:4466
```

### Authentication

Headlamp requires a bearer token. Generate one:

```bash
kubectl create token headlamp -n headlamp
```

Copy the output and paste it into the Headlamp login screen.

### Uninstall

```bash
./apps/headlamp/scripts/uninstall.sh
```

## Configuration

Edit `values.yaml` to customize:

| Key | Description | Default |
|-----|-------------|---------|
| `releaseName` | Helm release name | `headlamp` |
| `namespace` | Target namespace | `headlamp` |
| `image.tag` | Headlamp version | `v0.41.0` |
| `service.type` | Service type | `ClusterIP` |
| `resources` | CPU/memory requests & limits | 50m/128Mi ~ 200m/256Mi |

### Local Environment Options

**Option A: Port Forward (default)**
No extra configuration needed. Use `scripts/port-forward.sh`.

**Option B: NodePort**
Uncomment the `service` block at the bottom of `values.yaml`:

```yaml
service:
  type: NodePort
  port: 80
  nodePort: 30003
```

Then re-run `install.sh` and access via `http://<node-ip>:30003`.

**Option C: Ingress**
Set `ingress.enabled: true` in `values.yaml` and configure `hosts` and `tls`. Requires an Ingress Controller (e.g., ingress-nginx).

## Prerequisites

- Helm 3.x
- kubectl
- yq (optional; used to parse release/namespace from values.yaml)
- A running Kubernetes cluster

## References

- [Headlamp Documentation](https://headlamp.dev/docs/latest/)
- [Headlamp Helm Chart](https://github.com/headlamp-k8s/headlamp/tree/main/charts/headlamp)
- [Kubernetes SIG UI](https://github.com/kubernetes-sigs/headlamp)
