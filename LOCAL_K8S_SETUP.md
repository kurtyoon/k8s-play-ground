# Local Colima Kubernetes Setup

This repository is configured for a local Colima + K3s cluster with:

- **K3s** (v1.35.0+) with default CNI (`flannel`)
- **Traefik** as the ingress controller (K3s built-in, upgraded via Helm)
- **Gateway API** (v1.2.0 standard) with Traefik as GatewayClass
- **Headlamp** for cluster UI
- **web-filesystem** as a sample workload
- **VictoriaMetrics** + **VictoriaLogs** + **Grafana** for observability
- **Kyverno** for policy enforcement
- **cert-manager** for TLS automation
- Domain-based access via `*.local` (managed in `/etc/hosts`)

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│  headlamp   │     │web-filesystem│     │   kube-system   │
│   :4466     │     │   :3000      │     │   Traefik LB    │
└──────┬──────┘     └──────┬──────┘     └────────┬────────┘
       │                   │                      │
       └─────────┬─────────┴──────────────────────┘
                 │
          ┌──────┴──────┐
          │   Traefik   │  ← Ingress + Gateway (dual entry)
          │  Ingress    │
          │  HTTPRoute  │
          └──────┬──────┘
                 │
            ┌────┴────┐
            │ Node IP │  ← 192.168.64.2:80/443
            └────┬────┘
                 │
            ┌────┴────┐
            │  Host   │  ← /etc/hosts
            └─────────┘
```

## Prerequisites

- [Colima](https://github.com/abiosoft/colima) with `--network-address` (required for VM IP reachability)
- `kubectl`, `helm`
- macOS `/etc/hosts` or local DNS resolver

## Recreate Colima

```bash
colima stop
colima delete --force --data
colima start --cpu 4 --memory 8 --kubernetes --network-address
```

This creates a Colima VM with:
- 4 CPU cores
- 8 GiB RAM
- `--network-address` for routable VM IP
- K3s with Traefik enabled (default)

## Verify Cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Expected: single-node `colima` cluster, all pods `Running`.

## Install / Upgrade Traefik (Gateway API enabled)

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm upgrade --install traefik traefik/traefik \
  --namespace kube-system \
  --set "providers.kubernetesIngress.enabled=true" \
  --set "providers.kubernetesGateway.enabled=true" \
  --set "gateway.enabled=true" \
  --set "gateway.listeners.web.port=80" \
  --set "gateway.listeners.websecure.port=443" \
  --set "gateway.listeners.websecure.protocol=HTTPS" \
  --set "gateway.listeners.websecure.tls=true" \
  --set "gateway.listeners.websecure.tls.certificateRefs[0].name=traefik-default-cert" \
  --set "service.type=LoadBalancer"
```

## Install Gateway API CRDs

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

## Deploy Apps

### web-filesystem

```bash
kubectl apply -k apps/web-filesystem/k8s/overlays/local/
```

### Headlamp

```bash
./apps/headlamp/scripts/install.sh
```

## Configure /etc/hosts

Colima with Virtualization.Framework does **not** forward VM ports 80/443 to the macOS host. Instead, use `kubectl port-forward` via localhost:

```bash
sudo tee /etc/hosts <<'HOSTS'
127.0.0.1 localhost
127.0.0.1 headlamp.local grafana.local web-filesystem.local
HOSTS
sudo dscacheutil -flushcache
```

## Start Ingress Proxy

### Option A: Persistent Service (Recommended)

Run the setup script once. It creates a macOS `launchd` service that auto-starts on boot:

```bash
bash /tmp/setup-k8s-ingress.sh
```

This does three things:
1. Adds `127.0.0.1` entries to `/etc/hosts`
2. Creates a system service at `/Library/LaunchDaemons/com.k8s.traefik.ingress.plist`
3. Starts `kubectl port-forward` binding `127.0.0.1:80` → Traefik

After running, access directly in your browser:
- `http://headlamp.local`
- `http://grafana.local`
- `http://web-filesystem.local`

Manage the service:
```bash
sudo launchctl stop com.k8s.traefik.ingress    # stop
sudo launchctl start com.k8s.traefik.ingress   # start
sudo launchctl unload -w /Library/LaunchDaemons/com.k8s.traefik.ingress.plist  # disable
```

### Option B: Manual kubectl port-forward

If you prefer not to use a background service:

```bash
kubectl -n kube-system port-forward --address=127.0.0.1 svc/traefik 80:80
```

Keep this terminal open. Access the same URLs above.

## Verify Endpoints

```bash
curl -I http://headlamp.local
curl -I http://grafana.local/login
curl -I 'http://web-filesystem.local/api/files?path='
```

Expected: `HTTP/1.1 200 OK` for all.

### Via /etc/hosts (if Colima port forwarding works)

```bash
curl -I http://headlamp.local
curl -I http://web-filesystem.local
curl -I http://grafana.local
```

> Replace `192.168.64.2` in `/etc/hosts` with your actual Colima VM IP (`colima ls`).

## Access Headlamp

Open `http://headlamp.local` and authenticate with:

```bash
kubectl create token headlamp -n headlamp
```

Token expires in 24 hours by default. Re-run the command to refresh.

## Install Cluster Policies & Security

```bash
kubectl apply -f apps/cluster-policies/
```

This applies:
- **Pod Security Admission** labels on all namespaces
- **Kyverno** ClusterPolicies for security best practices
- **PriorityClasses** for workload scheduling
- **PodDisruptionBudgets** for availability
- **Default NetworkPolicies** for all namespaces
- **Event Exporter** for centralized event collection

## Install Observability Stack

```bash
./apps/observability/install.sh
```

This installs:
- **VictoriaMetrics Single** (time-series database with built-in scraping)
- **VictoriaLogs Single** (log database)
- **VictoriaLogs Collector** (DaemonSet log shipper)
- **kube-state-metrics** (Kubernetes object state metrics)
- **Grafana** (visualization with pre-configured datasources)

Access Grafana at `http://grafana.local` (anonymous login enabled for local dev).

## Cluster Security Hardening

### Per-Namespace Controls

Each app namespace includes:

- **Pod Security Admission** (`baseline` or `restricted` enforced)
- **Dedicated ServiceAccount** (`automountServiceAccountToken: false`)
- **Pod Security Context** (`runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL`)
- **NetworkPolicy** (default deny ingress + allow from Traefik only + DNS egress)
- **LimitRange** (default CPU/memory requests & limits)
- **ResourceQuota** (namespace-level resource caps)
- **PodDisruptionBudget** (minAvailable: 1 for critical workloads)

### Network Policies

Default policies applied to all namespaces:

| Policy | Scope | Purpose |
|--------|-------|---------|
| `default-deny-ingress` | All namespaces | Block all inbound traffic by default |
| `allow-dns-egress` | All namespaces | Allow UDP 53 to CoreDNS |
| `allow-dns-ingress` | `kube-system` | Allow CoreDNS to receive queries from all namespaces |
| `allow-traefik-ingress` | `headlamp`, `observability` | Allow Traefik (kube-system) to reach app ports (4466/3000) |
| `allow-traefik-egress` | `kube-system` | Allow Traefik to egress to backend services |
| `allow-ingress-from-traefik` | `web-filesystem` | Allow Traefik to reach web-filesystem pods |
| `allow-observability-internal` | `observability` | Allow intra-namespace pod communication |
| `allow-observability-ingress` | `observability` | Allow TCP 9428 (VictoriaLogs) within namespace |

> **Note:** When any ingress NetworkPolicy exists in a namespace, all unmatched ingress is denied by default (Kubernetes standard behavior). This is why `allow-observability-internal` is required for Grafana → VictoriaMetrics/VictoriaLogs communication.
>
> **Egress is also restricted:** The observability `allow-dns-egress` policy only permits specific outbound ports. If you add new components (e.g., kube-state-metrics on 8080), you must add the port to the egress policy.

### Cluster-Wide Controls

- **Kyverno** policies enforce:
  - Mandatory labels (`app.kubernetes.io/name`, `app.kubernetes.io/part-of`)
  - Resource limits/requests required
  - `latest` tag disallowed
  - Read-only root filesystem
  - Privilege escalation disabled
- **cert-manager** with self-signed ClusterIssuer ready for TLS certificates
- **PriorityClasses** for workload scheduling priority
- **Event Exporter** forwards all Kubernetes events to VictoriaLogs

### Event Exporter → VictoriaLogs

All Kubernetes events are collected by `event-exporter` and sent to VictoriaLogs via HTTP webhook:

```bash
# View recent events in VictoriaLogs
curl -s "http://grafana.local/api/datasources/proxy/uid/PD775F2863313E6C7/select/logsql/query?query=kind:Event"
```

Events include: Pod lifecycle, Policy violations, Resource scaling, Errors, Warnings.

### Grafana Dashboards

A pre-provisioned **"K8s Cluster Overview"** dashboard (uid: `k8s-overview`) is automatically loaded on install. It includes:

- Running Pods / Containers count
- Cluster CPU % and Memory %
- CPU / Memory usage by namespace
- Top 10 pods by CPU and memory
- Pod and container count over time

Datasource configuration:
| Datasource | Type | Endpoint |
|------------|------|----------|
| VictoriaMetrics | Prometheus | `http://victoria-metrics-victoria-metrics-single-server:8428` |
| VictoriaLogs | VictoriaLogs | `http://victoria-logs-victoria-logs-single-server:9428` |

Metrics sources:
| Source | Metrics |
|--------|---------|
| kubelet (cadvisor) | Container CPU, memory, pod counts |
| kube-state-metrics | Deployment, pod, node object states |
| VictoriaMetrics self | Scraper health and performance |

> Grafana admin credentials: `admin` / `admin`

## Gateway API Resources

```bash
kubectl get gateway -A
kubectl get httproute -A
kubectl get ingress -A
```

Current setup uses **both** Ingress and HTTPRoute for dual compatibility:
- `Ingress` → standard Kubernetes ingress
- `HTTPRoute` → Gateway API v1

## K9s

```bash
k9s
```

## Uninstall

```bash
# Headlamp
./apps/headlamp/scripts/uninstall.sh

# web-filesystem
kubectl delete -k apps/web-filesystem/k8s/overlays/local/

# Traefik
helm uninstall traefik -n kube-system

# Observability
helm uninstall grafana -n observability
helm uninstall victoria-metrics -n observability
helm uninstall victoria-logs -n observability
helm uninstall victoria-logs-collector -n observability
kubectl delete namespace observability

# Colima
colima delete
```

## Troubleshooting

### Ingress returns 502

**Cause:** Traefik (in `kube-system`) cannot reach backend pods.

**Check:**
```bash
# Verify Traefik egress policy exists
kubectl -n kube-system get networkpolicy allow-traefik-egress

# Verify backend ingress policy allows Traefik
kubectl -n <app-namespace> get networkpolicy
```

**Fix:** Ensure `allow-traefik-egress` in `kube-system` allows ports 3000/4466, and the app namespace has an ingress policy allowing those ports from `kube-system`.

### Grafana shows "DatasourceError" or no data

**Cause:** Grafana cannot reach VictoriaMetrics or VictoriaLogs.

**Check:**
```bash
# From Grafana pod, test connectivity
kubectl -n observability exec grafana-... -- wget -qO- \
  'http://victoria-metrics-victoria-metrics-single-server:8428/api/v1/query?query=up'
```

**Fix:** Ensure `allow-observability-internal` policy exists so observability pods can communicate with each other.

### Pod-to-pod connection refused

**Cause:** Kubernetes NetworkPolicy is stateless. When any ingress policy exists in a namespace, all unmatched ingress is denied.

**Fix:** Add explicit ingress rules for required ports, or add an intra-namespace policy like `allow-observability-internal`.

### Ingress returns 502 (after pod restart)

**Cause:** New pods get new IPs. If `allow-traefik-egress` is missing in `kube-system`, Traefik cannot reach backends.

**Fix:** Ensure `allow-traefik-egress` exists in `kube-system`:
```bash
kubectl get networkpolicy -n kube-system allow-traefik-egress
```

### DNS resolution fails inside pods

**Cause:** CoreDNS is blocked by `default-deny-ingress` in `kube-system`.

**Fix:** Ensure `allow-dns-ingress` exists in `kube-system` to allow UDP 53 from all namespaces.

### `headlamp.local` returns "This site can’t be reached"

**Cause:** `kubectl port-forward` is not running or `/etc/hosts` points to the VM IP instead of `127.0.0.1`.

**Fix:**
```bash
# Check hosts
cat /etc/hosts | grep headlamp
# Should show: 127.0.0.1 headlamp.local

# Check if proxy is running
sudo launchctl list | grep com.k8s.traefik.ingress

# If not running, start it
sudo launchctl start com.k8s.traefik.ingress
# Or re-run setup
bash /tmp/setup-k8s-ingress.sh
```

### `.local` domains return 502 from nginx

**Cause:** A Docker container `web-filesystem-local-proxy` may be squatting on VM port 80, intercepting all traffic before it reaches Traefik.

**Check:**
```bash
colima ssh -- docker ps | grep web-filesystem-local-proxy
```

**Fix:** Stop the conflicting container:
```bash
colima ssh -- docker stop web-filesystem-local-proxy
# Then re-run setup
bash /tmp/setup-k8s-ingress.sh
```

## Why This Layout

- **Traefik** is K3s default; upgrading it via Helm adds Gateway API support without adding new infrastructure.
- **Gateway API** provides a more expressive, role-oriented routing model than Ingress.
- **Ingress is retained** for backward compatibility and Helm chart defaults.
- **Flannel** is sufficient for a single-node local cluster; no need for Cilium/Calico overhead.
- **No MetalLB** needed; K3s Klipper LB (`svclb-traefik`) handles LoadBalancer services on single-node.
- **No cert-manager** for `.local` domains; HTTPS can be added later with a real domain.
- **VictoriaMetrics stack** is used instead of Prometheus for lighter resource usage while providing full metrics and log aggregation.
- **Grafana** provides visualization with pre-configured VictoriaMetrics and VictoriaLogs datasources.
