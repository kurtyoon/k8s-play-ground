# 아키텍처

## 전체 구조

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

## 책임 경계

| 영역 | 도구 | 책임 |
|---|---|---|
| OCI 인증/조회 | OCI CLI | 계정, 리전, 이미지, shape, 리소스 조회 |
| Cloud Infra | OpenTofu | VCN, subnet, route, security rule, compute 생성 |
| Node Bootstrap | Ansible | OS 설정, K3s 설치, worker join, kubeconfig 회수 |
| GitOps CD | Argo CD | platform/apps 지속 동기화 |
| Runtime Workflow | Argo Workflows | smoke test, backup, migration, restore drill |
| Bootstrap Secret | KSOPS/SOPS | GitOps bootstrap secret 암호화 관리 |
| Runtime Secret | OpenBao | internal secret source of truth |
| Secret Sync | External Secrets Operator | OpenBao secret을 Kubernetes Secret으로 동기화 |
| Policy | Kyverno | admission policy, baseline/security/network policy |
| Observability | Victoria Stack | metrics, logs, traces, alerting, UI |

## OCI VM 사양

| 노드 | 사양 | 역할 |
|---|---|---|
| master | 1 OCPU / 8GB | K3s server, platform core |
| worker-01 | 1 OCPU / 6GB | observability 중심 |
| worker-02 | 1 OCPU / 5GB | application workload |
| worker-03 | 1 OCPU / 5GB | application workload, spare |

총합: CPU 4 OCPU, Memory 24GB

## 설계 원칙

### 재현성

- VM과 네트워크는 OpenTofu로 재생성 가능해야 한다.
- OS/K3s bootstrap은 Ansible로 재실행 가능해야 한다.
- Kubernetes platform/apps는 Argo CD로 Git 상태와 동기화되어야 한다.

### 경량성

- 모든 core component는 소형 VM 사양에 맞게 requests/limits를 지정해야 한다.
- Observability는 single mode로 구성한다.
- retention은 짧게 유지한다.

### 보안

- SSH와 Kubernetes API는 개인 IP에서만 접근 가능해야 한다.
- plain secret은 Git에 commit하지 않는다.
- bootstrap secret은 SOPS/KSOPS로 암호화한다.
- runtime secret은 OpenBao를 source of truth로 삼는다.
- Kyverno policy는 Audit-first로 시작해 안정화 후 Enforce로 전환한다.

### 운영성

- 주요 장애 상황별 runbook을 작성한다.
- backup/restore 절차를 문서화한다.
- alert는 반드시 runbook과 연결한다.
- CI validation을 통해 GitOps 반영 전 오류를 줄인다.

## 비목표

이 프로젝트의 초기 범위에서 제외하는 항목:

- 3 master HA control-plane
- embedded etcd HA
- multi-cluster 운영
- service mesh
- Longhorn, Rook/Ceph 같은 distributed storage
- in-cluster CI runner 상시 운영
- VictoriaMetrics Cluster 모드
- 장기 로그/트레이스 보관
- 모든 Kyverno policy의 즉시 enforce
- 대규모 multi-tenant platform
- 실제 상용 서비스 수준의 SLA 보장

## 최종 전략

```text
Single-mode components
short retention
audit-first policy
backup-first reliability
external CI
App-of-Apps 유지
OpenTofu + Ansible + Argo CD 역할 분리
```

이 프로젝트는 HA Kubernetes 플랫폼이 아니라, 제한된 OCI 리소스 안에서 IaC, GitOps, Secret, Policy, Observability, Backup을 균형 있게 구현하는 production-like InfraOps platform lab이다.
