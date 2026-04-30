# Cluster Evolution Roadmap

This document outlines the phased evolution of `k8s-play-ground` from a local playground to a production-ready GitOps-managed cluster.

## Current State (Phase 0)

- Colima + K3s single-node cluster
- ArgoCD GitOps with App of Apps pattern
- Helm Operator pattern for all Helm-based applications
- Traefik Ingress + Gateway API
- Pod Security Admission, Kyverno, NetworkPolicies
- VictoriaMetrics + VictoriaLogs + Grafana observability stack

---

## Phase 1: Helm Operator Pattern (Done)

All Helm-based applications are now managed via ArgoCD `Application` resources using the **Helm source** with **multiple sources** (ArgoCD 2.6+).

This provides:
- Declarative Helm releases version-controlled in Git
- Independent lifecycle per application
- Native ArgoCD drift detection and self-healing
- No imperative `helm install` scripts required

### Applications Converted

| Application | Helm Repo | Chart |
|-------------|-----------|-------|
| headlamp | https://kubernetes-sigs.github.io/headlamp/ | headlamp |
| victoria-metrics | https://victoriametrics.github.io/helm-charts/ | victoria-metrics-single |
| victoria-logs | https://victoriametrics.github.io/helm-charts/ | victoria-logs-single |
| victoria-logs-collector | https://victoriametrics.github.io/helm-charts/ | victoria-logs-collector |
| kube-state-metrics | https://prometheus-community.github.io/helm-charts | kube-state-metrics |
| grafana | https://grafana.github.io/helm-charts | grafana |

---

## Phase 2: Secret Management & Automation

### 2.1 External Secrets Operator (ESO)

**Goal**: Eliminate manual secret creation and prevent secrets from being committed to Git.

**Approach**:
- Deploy ESO via ArgoCD Helm Application
- Configure `ClusterSecretStore` pointing to a backend (e.g., AWS Secrets Manager, HashiCorp Vault, or local `fake` store for dev)
- Create `ExternalSecret` resources in each app namespace
- All sensitive data (DB credentials, API keys, TLS certs) is pulled at runtime

**Impact**: Secrets are no longer managed imperatively with `kubectl create secret`.

### 2.2 Reloader (Stakater)

**Goal**: Automatically roll out Deployments/DaemonSets when ConfigMaps or Secrets change.

**Approach**:
- Deploy Reloader via ArgoCD Helm Application into `kube-system`
- Annotate workloads with `reloader.stakater.com/auto: "true"`
- When a referenced ConfigMap/Secret is updated, Reloader triggers a rolling restart

**Impact**: No manual pod restarts needed after configuration changes.

---

## Phase 3: Advanced Observability

### 3.1 Alerting Stack

**Goal**: Move from passive monitoring to active alerting.

**Components**:
- **VMAlert**: Rule evaluation and alert firing (part of VictoriaMetrics ecosystem)
- **Alertmanager**: Alert routing, grouping, and notification
- **VictoriaMetrics Alert Rules**: Kubernetes resource alerts, node health, pod crash loops

**Approach**:
- Add VMAlert and Alertmanager Helm values to observability stack
- Configure alert rules in Git (YAML)
- Configure Alertmanager receivers (Slack, PagerDuty, or webhook for local testing)

### 3.2 SLO Dashboards

**Goal**: Track service-level objectives.

**Approach**:
- Create Grafana dashboards for:
  - Availability (% of successful requests)
  - Latency (p50, p95, p99)
  - Error rate
  - Resource saturation

---

## Phase 4: Backup & Disaster Recovery

### 4.1 Velero

**Goal**: Backup cluster resources and persistent volumes.

**Approach**:
- Deploy Velero via Helm
- Configure backup schedules (e.g., daily full backup, hourly incremental)
- Use local S3-compatible storage (e.g., MinIO) for backup targets
- Test restore procedures regularly

---

## Phase 5: Security Hardening

### 5.1 RBAC Hardening

**Goal**: Principle of least privilege for all service accounts.

**Approach**:
- Audit all ClusterRoles and Roles
- Replace wildcard (`*`) permissions with explicit verbs/resources
- Disable default service account token automount where not needed
- Implement Pod Security Standards (PSS) at `restricted` level

### 5.2 Network Segmentation

**Goal**: Zero-trust networking between namespaces.

**Approach**:
- Add explicit allow policies for all inter-namespace communication
- Default deny all egress except required ports
- Implement Cilium (if moving beyond single-node) for L7 policies

### 5.3 Image Security

**Goal**: Prevent vulnerable or untrusted images from running.

**Approach**:
- Deploy Trivy Operator or Kyverno image verification policies
- Require signed images (cosign)
- Scan all images in CI before deployment

---

## Phase 6: GitOps Maturity

### 6.1 ArgoCD Image Updater

**Goal**: Automated deployment of new container images.

**Approach**:
- Deploy ArgoCD Image Updater
- Configure image update strategies per app (semver, latest, digest)
- Image Updater writes back to Git (commit & push) or updates Application directly

### 6.2 ArgoCD Notifications

**Goal**: Real-time notifications for sync events and failures.

**Approach**:
- Configure ArgoCD Notifications with triggers
- Send notifications to Slack/Discord/webhook
- Alert on sync failures, app degraded states

### 6.3 ArgoCD ApplicationSet

**Goal**: Templating and multi-environment management.

**Approach**:
- Replace root-app with ApplicationSet
- Use Git generators for app-of-apps pattern
- Deploy to multiple environments (dev, staging) from the same repo

---

## Phase 7: Platform Services

### 7.1 Ingress TLS (cert-manager)

**Goal**: Automated TLS for all ingress endpoints.

**Approach**:
- Configure cert-manager with Let's Encrypt (staging for local) or self-signed ClusterIssuer
- Add TLS blocks to all Ingress resources
- Enable HTTP→HTTPS redirect in Traefik

### 7.2 Node Local DNS Cache

**Goal**: Reduce DNS latency and improve reliability.

**Approach**:
- Deploy NodeLocal DNSCache DaemonSet
- Configure Kubelet to use local cache for cluster DNS

### 7.3 Descheduler

**Goal**: Improve cluster resource utilization.

**Approach**:
- Deploy Kubernetes Descheduler
- Enable strategies: RemoveDuplicates, LowNodeUtilization, RemoveFailedPods

---

## Implementation Priority

| Phase | Effort | Impact | Priority |
|-------|--------|--------|----------|
| Phase 1 | Low | High | Done |
| Phase 2 | Medium | High | Next |
| Phase 3 | Medium | High | Next |
| Phase 4 | Medium | Medium | Later |
| Phase 5 | High | High | Later |
| Phase 6 | Medium | Medium | Later |
| Phase 7 | Low-Medium | Medium | Later |

---

## Contributing

When adding a new phase:
1. Create an issue describing the goal and approach
2. Implement ArgoCD Applications or manifests in `apps/`
3. Update this roadmap with the completed phase
4. Ensure CI passes before merging
