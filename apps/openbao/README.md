# OpenBao - Secret Management

> Declarative Helm-based deployment for [OpenBao](https://openbao.org/)
> Community-driven secret management fork of HashiCorp Vault

## Architecture

This directory follows the GitOps Helm Application pattern.

```
values.yaml      <-- Desired state (declarative)
     |
     v
ArgoCD Application  --> Automated sync to cluster
```

OpenBao is deployed in **single-node integrated storage (Raft)** mode with a persistent volume. This is not dev mode — it demonstrates production patterns (Raft storage, persistence) on a constrained local cluster.

## Directory Layout

```
apps/openbao/
├── values.yaml           # Helm values (desired state)
└── README.md             # This file
```

## Quick Start

### Install / Upgrade (via ArgoCD)

```bash
kubectl apply -f argocd/apps/openbao.yaml
```

Or wait for the root app to sync it automatically.

### Initialize and Unseal (One-Time)

OpenBao deploys in a sealed state. Run once after the pod is ready:

```bash
kubectl exec -it openbao-0 -n vault -- bao operator init -key-shares=1 -key-threshold=1
```

Save the **Unseal Key** and **Initial Root Token**, then unseal:

```bash
kubectl exec -it openbao-0 -n vault -- bao operator unseal <UNSEAL_KEY>
```

### Access UI

Open `http://openbao.local` and authenticate with the root token.

### Configure Kubernetes Auth for ESO

After initialization, enable Kubernetes authentication so External Secrets Operator can sync secrets:

```bash
kubectl exec -it openbao-0 -n vault -- sh
export VAULT_TOKEN=<ROOT_TOKEN>

bao auth enable kubernetes
bao write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)"

bao policy write external-secrets - <<EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF

bao write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=external-secrets \
  ttl=1h
```

## Configuration

Edit `values.yaml` to customize:

| Key | Description | Default |
|-----|-------------|---------|
| `server.image.tag` | OpenBao version | `2.2.0` |
| `server.standalone.enabled` | Single-node mode | `true` |
| `server.dataStorage.size` | Raft data volume size | `2Gi` |
| `ingress.hosts[0].host` | Ingress hostname | `openbao.local` |
| `resources` | CPU/memory requests & limits | 100m/256Mi ~ 500m/512Mi |

## Prerequisites

- ArgoCD must be running in the cluster
- Traefik ingress controller must allow egress to port 8200
- `/etc/hosts` must contain `127.0.0.1 openbao.local`

## References

- [OpenBao Documentation](https://openbao.org/docs/)
- [OpenBao Helm Chart](https://github.com/openbao/openbao-helm)
- [External Secrets Operator - Vault Provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
