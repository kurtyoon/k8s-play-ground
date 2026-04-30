# Keycloak - OIDC Identity Provider

> Declarative Helm-based deployment for [Keycloak](https://www.keycloak.org/)
> Open-source Identity and Access Management

## Architecture

This directory follows the GitOps Helm Application pattern used by other apps in this repo.

```
values.yaml      <-- Desired state (declarative)
     |
     v
ArgoCD Application  --> Automated sync to cluster
```

### Why Bitnami Chart?

The Bitnami Keycloak chart bundles a PostgreSQL subchart, making it a single-command install suitable for a local playground. For production environments, consider the codecentric/keycloakx chart with an external managed PostgreSQL.

## Directory Layout

```
apps/keycloak/
├── values.yaml           # Helm values (desired state)
└── README.md             # This file
```

## Quick Start

### Install / Upgrade (via ArgoCD)

```bash
kubectl apply -f argocd/apps/keycloak.yaml
```

Or wait for the root app to sync it automatically.

### Access

Open `http://keycloak.local` and log in with:
- **Username:** `admin`
- **Password:** `admin`

> **Security note:** These credentials are for local development only. Rotate them immediately for any non-local deployment.

### Token Generation (for app OIDC setup)

Once a realm and client are configured, you can test token issuance:

```bash
curl -X POST "http://keycloak.local/realms/{realm}/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id={client-id}" \
  -d "client_secret={client-secret}"
```

## Configuration

Edit `values.yaml` to customize:

| Key | Description | Default |
|-----|-------------|---------|
| `replicaCount` | Keycloak replicas | `1` |
| `image.tag` | Keycloak version | `26.2.0-debian-12-r0` |
| `auth.adminUser` | Bootstrap admin username | `admin` |
| `auth.adminPassword` | Bootstrap admin password | `admin` |
| `postgresql.enabled` | Enable built-in PostgreSQL | `true` |
| `ingress.hostname` | Ingress hostname | `keycloak.local` |
| `resources` | CPU/memory requests & limits | 200m/512Mi ~ 1000m/1Gi |

## Prerequisites

- ArgoCD must be running in the cluster
- Traefik ingress controller must allow egress to port 8080
- `/etc/hosts` must contain `127.0.0.1 keycloak.local`

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Bitnami Keycloak Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/keycloak)
