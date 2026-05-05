# OCI K3s GitOps Lab

Oracle Cloud Infrastructure 위에 K3s 기반 production-like Kubernetes 플랫폼을 구축하는 InfraOps/GitOps 실습 프로젝트입니다.

## 개요

개인 Mac에서는 Colima + K3s 기반 local cluster를 사용해 manifest, GitOps, policy, secret, observability 구성을 빠르게 검증합니다. 이후 OCI VM 4대로 구성된 K3s 클러스터에 동일한 GitOps repo를 기반으로 운영형 구성을 반영합니다.

이 프로젝트는 단순 Kubernetes 설치가 아니라, 다음 운영 체계를 함께 다룹니다.

- **OpenTofu** 기반 OCI 인프라 프로비저닝
- **Ansible** 기반 OS/K3s bootstrap
- **Argo CD** 기반 GitOps 배포
- **KSOPS/SOPS** 기반 bootstrap secret 관리
- **OpenBao** 기반 internal secret 관리
- **External Secrets Operator** 기반 secret 동기화
- **Kyverno** 기반 policy-as-code
- **Victoria Stack** 기반 Monitoring, Logging, Tracing
- **Backup/Restore** 및 운영 Runbook

## 아키텍처

```text
Developer Mac
├── Colima + K3s local cluster
├── OCI CLI
├── OpenTofu
├── Ansible
├── kubectl
└── argocd CLI

GitHub Repository
└── oci-k3s-gitops-lab
    ├── infra/oci/tofu
    ├── ansible
    ├── bootstrap
    ├── clusters
    ├── platform
    ├── apps
    └── workflows

OCI
└── VCN
    └── Public Subnet
        ├── master: K3s server
        ├── worker-01: observability
        ├── worker-02: apps
        └── worker-03: apps/spare
```

## Repository 구조

```
.
├── README.md
├── Makefile
├── .gitignore
├── .sops.yaml
│
├── docs/                    # 문서
│   ├── ARCHITECTURE.md
│   ├── LOCAL_COLIMA.md
│   ├── OCI_K3S.md
│   ├── SECRET_MANAGEMENT.md
│   ├── POLICY_MANAGEMENT.md
│   ├── OBSERVABILITY.md
│   ├── BACKUP_RESTORE.md
│   ├── UPGRADE_STRATEGY.md
│   ├── INCIDENT_RESPONSE.md
│   ├── COST_MANAGEMENT.md
│   └── TROUBLESHOOTING.md
│
├── infra/                   # 인프라 프로비저닝
│   └── oci/
│       ├── tofu/            # OpenTofu manifests
│       └── scripts/         # helper scripts
│
├── ansible/                 # 노드 bootstrap
│   ├── inventory/
│   ├── group_vars/
│   ├── playbooks/
│   └── roles/
│
├── bootstrap/               # 클러스터 bootstrap
│   ├── local-colima/
│   └── oci-k3s/
│
├── clusters/                # Argo CD root apps
│   ├── local/
│   └── oci-prod/
│
├── platform/                # Platform components
│   ├── argocd/
│   ├── ingress/
│   ├── cert-manager/
│   ├── secrets/
│   ├── policy/
│   ├── observability/
│   └── workflows/
│
└── apps/                    # Applications
```

## Quick Start

### Local Cluster

```bash
# Colima + K3s local cluster 생성
make local-up

# Argo CD local root app 적용
kubectl apply -f clusters/local/root-app.yaml

# local cluster 종료
make local-down
```

### OCI Cluster

```bash
# OCI 인증 확인
make oci-check

# 인프라 생성
make infra-init
make infra-plan
make infra-apply

# Ansible inventory 생성
make inventory

# K3s 클러스터 bootstrap
make k3s-install

# Argo CD GitOps 적용
make argocd-bootstrap
make oci-sync
```

## 주요 문서

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — 전체 아키텍처 및 설계 결정
- [LOCAL_COLIMA.md](docs/LOCAL_COLIMA.md) — Local 개발 환경 구성
- [OCI_K3S.md](docs/OCI_K3S.md) — OCI K3s 클러스터 구성
- [SECRET_MANAGEMENT.md](docs/SECRET_MANAGEMENT.md) — Secret 관리 체계
- [POLICY_MANAGEMENT.md](docs/POLICY_MANAGEMENT.md) — Policy 관리
- [OBSERVABILITY.md](docs/OBSERVABILITY.md) — Observability 구성
- [BACKUP_RESTORE.md](docs/BACKUP_RESTORE.md) — Backup/Restore 절차
- [UPGRADE_STRATEGY.md](docs/UPGRADE_STRATEGY.md) — Upgrade 전략
- [INCIDENT_RESPONSE.md](docs/INCIDENT_RESPONSE.md) — 장애 대응 Runbook
- [COST_MANAGEMENT.md](docs/COST_MANAGEMENT.md) — 비용 관리
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 문제 해결 가이드

## 라이선스

MIT
