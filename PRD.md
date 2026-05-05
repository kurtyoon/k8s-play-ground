# PRD: OCI K3s GitOps Lab

## 1. 문서 정보

| 항목 | 내용 |
|---|---|
| 프로젝트명 | OCI K3s GitOps Lab |
| 추천 repo 이름 | `oci-k3s-gitops-lab` |
| 문서 유형 | Product Requirements Document |
| 대상 사용자 | 개인 InfraOps / Platform Engineering 학습 및 운영 실습 |
| 주요 환경 | 개인 Mac, Oracle Cloud Infrastructure, K3s |
| 작성 목적 | local K3s 테스트 환경과 OCI VM 기반 production-like K3s 클러스터를 IaC, Configuration Management, GitOps, Secret Management, Policy Management, Observability 방식으로 구축하기 위한 실행 계획 정의 |

---

## 2. 프로젝트 개요

`oci-k3s-gitops-lab`은 Oracle Cloud Infrastructure 위에 K3s 기반 production-like Kubernetes 플랫폼을 구축하는 InfraOps/GitOps 실습 프로젝트이다.

개인 Mac에서는 Colima + K3s 기반 local cluster를 사용해 manifest, GitOps, policy, secret, observability 구성을 빠르게 검증한다. 이후 OCI VM 4대로 구성된 K3s 클러스터에 동일한 GitOps repo를 기반으로 운영형 구성을 반영한다.

이 프로젝트는 단순 Kubernetes 설치가 아니라, 다음 운영 체계를 함께 다룬다.

- OpenTofu 기반 OCI 인프라 프로비저닝
- Ansible 기반 OS/K3s bootstrap
- Argo CD 기반 GitOps 배포
- KSOPS/SOPS 기반 bootstrap secret 관리
- OpenBao 기반 internal secret 관리
- External Secrets Operator 기반 secret 동기화
- Kyverno 기반 policy-as-code
- Victoria Stack 기반 Monitoring, Logging, Tracing
- Backup/Restore 및 운영 Runbook

---

## 3. 문제 정의

현재 Kubernetes local cluster는 Colima/K3s 기반으로 구성되어 있으며, 개인 Mac에서 실험하기에는 적합하다. 그러나 실제 운영형 클러스터와는 다음 차이가 있다.

- Colima는 local runtime일 뿐, 운영 환경이 아니다.
- local cluster와 OCI VM cluster의 bootstrap 방식이 다르다.
- VM, 네트워크, 보안 규칙, K3s 설치가 재현 가능하게 자동화되어야 한다.
- secret, policy, observability, backup이 체계적으로 관리되어야 한다.
- 운영 클러스터가 HA 구성은 아니므로, 고가용성보다 복구 가능성과 재현성에 집중해야 한다.

따라서 이 프로젝트는 “운영 HA 클러스터”가 아니라 “소형 production-like GitOps platform lab”으로 정의한다.

---

## 4. 목표

### 4.1 제품 목표

- 개인 Mac local cluster에서 검증한 Kubernetes manifest를 OCI VM 기반 K3s 클러스터에 일관되게 반영한다.
- OCI VM 4대 기반 K3s 클러스터를 OpenTofu와 Ansible로 재현 가능하게 구축한다.
- Argo CD App-of-Apps 패턴으로 platform component와 application을 GitOps 방식으로 관리한다.
- KSOPS, OpenBao, ESO를 통해 bootstrap secret과 runtime secret의 역할을 분리한다.
- Kyverno를 통해 Kubernetes policy guardrail을 적용한다.
- Victoria UI 중심의 Monitoring, Logging, Tracing 체계를 구성한다.
- 백업/복구, 업그레이드, 장애 대응 Runbook을 작성해 운영 성숙도를 높인다.

### 4.2 학습 목표

- 회사 스택과 유사한 OpenTofu 기반 IaC 흐름을 개인 프로젝트에서 체화한다.
- OCI, K3s, Ansible, Argo CD, Secret Management, Policy Management, Observability를 하나의 운영 흐름으로 연결한다.
- 단순 설치가 아니라 복구 가능하고 반복 가능한 클러스터 운영 모델을 만든다.

---

## 5. 비목표

이 프로젝트의 초기 범위에서 제외하는 항목은 다음과 같다.

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

---

## 6. 현재 제약 조건

### 6.1 OCI VM 사양

| 노드 | 사양 | 역할 |
|---|---:|---|
| master | 1 OCPU / 8GB | K3s server, platform core |
| worker-01 | 1 OCPU / 6GB | observability 중심 |
| worker-02 | 1 OCPU / 5GB | application workload |
| worker-03 | 1 OCPU / 5GB | application workload, spare |

총합:

- CPU: 4 OCPU
- Memory: 24GB

### 6.2 주요 병목

- CPU가 가장 큰 병목이다.
- control-plane은 단일 master라 HA가 아니다.
- observability stack은 single mode와 짧은 retention이 필요하다.
- 모든 controller/operator를 동시에 무겁게 운영하면 CPU pressure가 발생할 수 있다.

---

## 7. 최종 아키텍처

### 7.1 전체 구조

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

### 7.2 책임 경계

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

---

## 8. Repository 구조

```text
oci-k3s-gitops-lab/
├── README.md
├── Makefile
├── .gitignore
├── .sops.yaml
│
├── docs/
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
├── infra/
│   └── oci/
│       ├── tofu/
│       │   ├── versions.tf
│       │   ├── provider.tf
│       │   ├── variables.tf
│       │   ├── locals.tf
│       │   ├── network.tf
│       │   ├── security.tf
│       │   ├── compute.tf
│       │   ├── outputs.tf
│       │   └── terraform.tfvars.example
│       └── scripts/
│           ├── oci-check.sh
│           ├── render-inventory.sh
│           └── ssh-test.sh
│
├── ansible/
│   ├── inventory/
│   │   └── oci.ini
│   ├── group_vars/
│   │   └── all.yaml
│   ├── playbooks/
│   │   ├── site.yaml
│   │   ├── 00-bootstrap-os.yaml
│   │   ├── 10-install-k3s-server.yaml
│   │   ├── 20-install-k3s-agents.yaml
│   │   ├── 30-fetch-kubeconfig.yaml
│   │   └── 40-bootstrap-argocd.yaml
│   └── roles/
│       ├── common/
│       ├── k3s_server/
│       ├── k3s_agent/
│       └── argocd_bootstrap/
│
├── bootstrap/
│   ├── local-colima/
│   └── oci-k3s/
│
├── clusters/
│   ├── local/
│   │   ├── root-app.yaml
│   │   └── projects.yaml
│   └── oci-prod/
│       ├── root-app.yaml
│       └── projects.yaml
│
├── platform/
│   ├── argocd/
│   ├── ingress/
│   ├── cert-manager/
│   ├── secrets/
│   │   ├── ksops/
│   │   ├── external-secrets/
│   │   └── openbao/
│   ├── policy/
│   │   └── kyverno/
│   ├── observability/
│   │   ├── metrics/
│   │   ├── logging/
│   │   ├── tracing/
│   │   ├── alerting/
│   │   └── ui/
│   └── workflows/
│
└── apps/
    └── web-filesystem/
        ├── base/
        └── overlays/
            ├── local/
            └── oci-prod/
```

---

## 9. 주요 사용자 시나리오

### 9.1 Local cluster 생성

```text
사용자는 개인 Mac에서 Colima + K3s local cluster를 생성한다.
Argo CD local root app을 적용한다.
local overlay 기반 platform/apps를 배포한다.
변경사항을 빠르게 검증한다.
```

### 9.2 OCI 인프라 생성

```text
사용자는 OCI CLI 인증을 확인한다.
OpenTofu로 VCN, subnet, security rule, VM 4대를 생성한다.
OpenTofu output을 Ansible inventory로 변환한다.
```

### 9.3 K3s 클러스터 bootstrap

```text
사용자는 Ansible playbook을 실행한다.
master에 K3s server를 설치한다.
worker 3대를 K3s agent로 join한다.
개인 Mac으로 kubeconfig를 회수한다.
```

### 9.4 GitOps bootstrap

```text
사용자는 Ansible 또는 kubectl로 Argo CD를 최초 설치한다.
clusters/oci-prod/root-app.yaml을 적용한다.
Argo CD가 platform/apps를 동기화한다.
```

### 9.5 Secret 운영

```text
초기 bootstrap secret은 KSOPS/SOPS로 암호화해 Git에서 관리한다.
runtime secret은 OpenBao에 저장한다.
External Secrets Operator가 OpenBao secret을 Kubernetes Secret으로 동기화한다.
Reloader는 Secret 변경 시 workload rollout을 수행한다.
```

### 9.6 Policy 운영

```text
Kyverno policy를 GitOps로 배포한다.
초기에는 Audit 중심으로 적용한다.
안정화 후 selected policy를 Enforce로 전환한다.
```

### 9.7 Observability 운영

```text
VictoriaMetrics로 metrics를 수집한다.
VictoriaLogs로 logs를 수집한다.
VictoriaTraces로 traces를 수집한다.
Victoria UI를 통해 metrics/logs/traces를 탐색한다.
VMAlert와 Alertmanager로 핵심 alert를 처리한다.
```

---

## 10. 기능 요구사항

### 10.1 Infra Provisioning

| ID | 요구사항 | 우선순위 |
|---|---|---|
| INFRA-001 | OpenTofu로 OCI VCN을 생성할 수 있어야 한다. | P0 |
| INFRA-002 | OpenTofu로 subnet, route table, internet gateway를 생성할 수 있어야 한다. | P0 |
| INFRA-003 | OpenTofu로 security rule 또는 NSG를 생성할 수 있어야 한다. | P0 |
| INFRA-004 | OpenTofu로 K3s용 VM 4대를 생성할 수 있어야 한다. | P0 |
| INFRA-005 | VM public/private IP를 output으로 제공해야 한다. | P0 |
| INFRA-006 | OpenTofu output에서 Ansible inventory를 생성해야 한다. | P0 |
| INFRA-007 | OpenTofu state는 git에 commit되지 않아야 한다. | P0 |
| INFRA-008 | 장기적으로 OCI Object Storage 기반 remote state를 검토한다. | P1 |

### 10.2 Node Bootstrap

| ID | 요구사항 | 우선순위 |
|---|---|---|
| NODE-001 | Ansible로 OS 기본 패키지를 설치해야 한다. | P0 |
| NODE-002 | Ansible로 swap off, sysctl, hostname 설정을 적용해야 한다. | P0 |
| NODE-003 | Ansible로 K3s server를 master에 설치해야 한다. | P0 |
| NODE-004 | Ansible로 K3s agent를 worker에 join해야 한다. | P0 |
| NODE-005 | Ansible로 kubeconfig를 개인 Mac으로 회수해야 한다. | P0 |
| NODE-006 | Ansible playbook은 idempotent해야 한다. | P0 |
| NODE-007 | master/worker node label을 적용해야 한다. | P1 |
| NODE-008 | master workload scheduling 정책을 정의해야 한다. | P1 |

### 10.3 GitOps

| ID | 요구사항 | 우선순위 |
|---|---|---|
| GITOPS-001 | Argo CD를 클러스터에 bootstrap해야 한다. | P0 |
| GITOPS-002 | App-of-Apps root app을 local/oci-prod로 분리해야 한다. | P0 |
| GITOPS-003 | platform/apps는 Argo CD로 지속 동기화되어야 한다. | P0 |
| GITOPS-004 | sync wave를 정의해야 한다. | P1 |
| GITOPS-005 | AppProject를 통해 platform/apps 권한을 분리해야 한다. | P1 |
| GITOPS-006 | 장기적으로 ApplicationSet 전환을 검토한다. | P2 |

### 10.4 Secret Management

| ID | 요구사항 | 우선순위 |
|---|---|---|
| SEC-001 | SOPS + age 기반 암호화 정책을 정의해야 한다. | P0 |
| SEC-002 | KSOPS를 Argo CD/Kustomize와 연동해야 한다. | P0 |
| SEC-003 | bootstrap secret은 SOPS encrypted manifest로 관리해야 한다. | P0 |
| SEC-004 | OpenBao single instance를 배포해야 한다. | P1 |
| SEC-005 | OpenBao backup/restore 절차를 문서화해야 한다. | P1 |
| SEC-006 | External Secrets Operator를 배포해야 한다. | P1 |
| SEC-007 | OpenBao와 ESO를 연동해야 한다. | P1 |
| SEC-008 | Reloader를 통해 Secret 변경 시 rollout을 지원해야 한다. | P2 |
| SEC-009 | secret rotation runbook을 작성해야 한다. | P2 |

### 10.5 Policy Management

| ID | 요구사항 | 우선순위 |
|---|---|---|
| POL-001 | Kyverno controller를 배포해야 한다. | P0 |
| POL-002 | baseline policy를 Audit 모드로 적용해야 한다. | P0 |
| POL-003 | privileged container 금지 policy를 적용해야 한다. | P1 |
| POL-004 | latest image tag 금지 policy를 적용해야 한다. | P1 |
| POL-005 | requests/limits 필수 policy를 적용해야 한다. | P1 |
| POL-006 | LoadBalancer Service 제한 policy를 적용해야 한다. | P1 |
| POL-007 | plain Secret 생성 제한 policy를 검토해야 한다. | P2 |
| POL-008 | observability namespace 예외 정책을 정의해야 한다. | P1 |

### 10.6 Observability

| ID | 요구사항 | 우선순위 |
|---|---|---|
| OBS-001 | VictoriaMetrics Operator를 배포해야 한다. | P0 |
| OBS-002 | VMSingle을 single mode로 배포해야 한다. | P0 |
| OBS-003 | VMAgent를 통해 metrics를 수집해야 한다. | P0 |
| OBS-004 | kube-state-metrics를 수집해야 한다. | P0 |
| OBS-005 | VictoriaLogs Single을 배포해야 한다. | P1 |
| OBS-006 | VictoriaLogs Collector로 container logs를 수집해야 한다. | P1 |
| OBS-007 | VictoriaTraces Single을 배포해야 한다. | P2 |
| OBS-008 | OpenTelemetry Collector를 배포해야 한다. | P2 |
| OBS-009 | Victoria UI를 노출해야 한다. | P1 |
| OBS-010 | VMAlert와 Alertmanager를 배포해야 한다. | P2 |
| OBS-011 | 핵심 alert rule과 runbook을 연결해야 한다. | P2 |

### 10.7 Backup / Restore

| ID | 요구사항 | 우선순위 |
|---|---|---|
| BAK-001 | OpenTofu state backup 정책을 정의해야 한다. | P0 |
| BAK-002 | K3s snapshot 절차를 작성해야 한다. | P0 |
| BAK-003 | K3s restore runbook을 작성해야 한다. | P1 |
| BAK-004 | OpenBao backup/restore runbook을 작성해야 한다. | P1 |
| BAK-005 | Victoria stack PVC backup 정책을 정의해야 한다. | P2 |
| BAK-006 | restore drill을 최소 1회 수행하고 기록해야 한다. | P2 |

### 10.8 CI Validation

| ID | 요구사항 | 우선순위 |
|---|---|---|
| CI-001 | tofu fmt/validate를 CI에서 수행해야 한다. | P1 |
| CI-002 | ansible-lint를 CI에서 수행해야 한다. | P1 |
| CI-003 | kustomize build를 CI에서 수행해야 한다. | P1 |
| CI-004 | kubeconform으로 Kubernetes schema 검증을 수행해야 한다. | P1 |
| CI-005 | kyverno test를 CI에서 수행해야 한다. | P2 |
| CI-006 | gitleaks 또는 secret scan을 수행해야 한다. | P1 |
| CI-007 | cluster 내부 self-hosted runner는 초기 범위에서 제외한다. | P0 |

---

## 11. 비기능 요구사항

### 11.1 재현성

- VM과 네트워크는 OpenTofu로 재생성 가능해야 한다.
- OS/K3s bootstrap은 Ansible로 재실행 가능해야 한다.
- Kubernetes platform/apps는 Argo CD로 Git 상태와 동기화되어야 한다.

### 11.2 경량성

- 모든 core component는 소형 VM 사양에 맞게 requests/limits를 지정해야 한다.
- Observability는 single mode로 구성한다.
- retention은 짧게 유지한다.

### 11.3 보안

- SSH와 Kubernetes API는 개인 IP에서만 접근 가능해야 한다.
- plain secret은 Git에 commit하지 않는다.
- bootstrap secret은 SOPS/KSOPS로 암호화한다.
- runtime secret은 OpenBao를 source of truth로 삼는다.
- Kyverno policy는 Audit-first로 시작해 안정화 후 Enforce로 전환한다.

### 11.4 운영성

- 주요 장애 상황별 runbook을 작성한다.
- backup/restore 절차를 문서화한다.
- alert는 반드시 runbook과 연결한다.
- CI validation을 통해 GitOps 반영 전 오류를 줄인다.

---

## 12. 단계별 실행 계획

## Phase 0. Repo 초기화

목표: repo 이름과 구조를 확정하고 기본 문서를 만든다.

작업:

- [ ] repo 이름을 `oci-k3s-gitops-lab`으로 확정
- [ ] README.md 작성
- [ ] Makefile 기본 골격 작성
- [ ] `.gitignore` 작성
- [ ] docs 디렉터리 생성
- [ ] `docs/ARCHITECTURE.md` 초안 작성
- [ ] 기존 `k8s-play-ground` 내용 중 유지할 manifest 정리

완료 기준:

- repo 구조가 정의되어 있다.
- local/oci-prod의 방향이 README에 설명되어 있다.

---

## Phase 1. Local Colima/K3s 정리

목표: 개인 Mac에서 local 테스트 환경을 재현 가능하게 만든다.

작업:

- [ ] `bootstrap/local-colima/start.sh` 작성
- [ ] `bootstrap/local-colima/stop.sh` 작성
- [ ] `bootstrap/local-colima/destroy.sh` 작성
- [ ] local Argo CD bootstrap 스크립트 작성
- [ ] `clusters/local/root-app.yaml` 작성
- [ ] local overlay 경로 정리
- [ ] Headlamp/web-filesystem 등 local app 검증

완료 기준:

- `make local-up`으로 Colima/K3s가 생성된다.
- `clusters/local/root-app.yaml` 적용 후 local platform/app이 배포된다.

---

## Phase 2. OCI OpenTofu 인프라 구성

목표: OCI VM 4대와 네트워크를 OpenTofu로 생성한다.

작업:

- [ ] `infra/oci/tofu/versions.tf` 작성
- [ ] `provider.tf` 작성
- [ ] `variables.tf` 작성
- [ ] `network.tf` 작성
- [ ] `security.tf` 작성
- [ ] `compute.tf` 작성
- [ ] `outputs.tf` 작성
- [ ] `terraform.tfvars.example` 작성
- [ ] `infra/oci/scripts/oci-check.sh` 작성
- [ ] OpenTofu output JSON 생성
- [ ] Ansible inventory 렌더링 스크립트 작성

완료 기준:

- `make infra-plan`이 성공한다.
- `make infra-apply` 후 VM 4대가 생성된다.
- `make inventory`로 Ansible inventory가 생성된다.

---

## Phase 3. Ansible K3s Bootstrap

목표: OCI VM에 K3s 클러스터를 재현 가능하게 설치한다.

작업:

- [ ] `ansible/playbooks/00-bootstrap-os.yaml` 작성
- [ ] `10-install-k3s-server.yaml` 작성
- [ ] `20-install-k3s-agents.yaml` 작성
- [ ] `30-fetch-kubeconfig.yaml` 작성
- [ ] `40-bootstrap-argocd.yaml` 작성
- [ ] `site.yaml` 작성
- [ ] node label 적용
- [ ] kubeconfig endpoint 치환
- [ ] idempotency 검증

완료 기준:

- `make ansible-ping` 성공
- `make k3s-install` 성공
- `kubectl get nodes`에서 4대 노드 Ready
- 개인 Mac에서 OCI K3s kubeconfig 사용 가능

---

## Phase 4. Argo CD GitOps 구성

목표: OCI cluster에서 platform/apps를 Argo CD로 관리한다.

작업:

- [ ] `clusters/oci-prod/root-app.yaml` 작성
- [ ] `clusters/oci-prod/projects.yaml` 작성
- [ ] App-of-Apps 구조 정리
- [ ] sync wave annotation 적용
- [ ] `platform/argocd` 구성
- [ ] `apps/web-filesystem` local/oci-prod overlay 분리
- [ ] Argo CD self-heal/prune 정책 검토

완료 기준:

- Argo CD에서 oci-prod root app이 Healthy/Synced 상태
- platform/apps가 GitOps로 배포된다.
- local overlay와 oci-prod overlay가 분리되어 있다.

---

## Phase 5. Secret Management

목표: KSOPS와 OpenBao 기반 secret 관리 체계를 구성한다.

작업:

- [ ] `.sops.yaml` 작성
- [ ] age key 생성 및 보관 정책 작성
- [ ] KSOPS Argo CD 연동
- [ ] SOPS encrypted secret 예시 작성
- [ ] OpenBao single 배포
- [ ] OpenBao 초기화/unseal 절차 문서화
- [ ] External Secrets Operator 배포
- [ ] OpenBao SecretStore/ExternalSecret 연동
- [ ] Reloader 적용 검토
- [ ] `docs/SECRET_MANAGEMENT.md` 작성

완료 기준:

- Git에 plaintext secret이 없다.
- KSOPS로 encrypted secret이 배포된다.
- OpenBao secret이 ESO를 통해 Kubernetes Secret으로 동기화된다.

---

## Phase 6. Policy Management

목표: Kyverno 기반 policy guardrail을 적용한다.

작업:

- [ ] Kyverno controller 배포
- [ ] baseline policy 작성
- [ ] secret policy 작성
- [ ] networking policy 작성
- [ ] gitops policy 작성
- [ ] observability exception policy 작성
- [ ] local은 Audit 중심 적용
- [ ] oci-prod는 selected Enforce 적용
- [ ] `docs/POLICY_MANAGEMENT.md` 작성

완료 기준:

- Kyverno policy가 Argo CD로 배포된다.
- policy violation이 확인 가능하다.
- 최소 2개 이상의 위험 정책이 Enforce된다.

---

## Phase 7. Observability

목표: Victoria UI 중심의 Monitoring, Logging, Tracing 기반을 구성한다.

작업:

- [ ] VictoriaMetrics Operator 배포
- [ ] VMSingle 배포
- [ ] VMAgent 배포
- [ ] kube-state-metrics 연동
- [ ] VictoriaLogs Single 배포
- [ ] VictoriaLogs Collector 배포
- [ ] Victoria UI ingress 구성
- [ ] VictoriaTraces Single 배포
- [ ] OpenTelemetry Collector 배포
- [ ] VMAlert/Alertmanager 배포
- [ ] 핵심 alert rule 작성
- [ ] `docs/OBSERVABILITY.md` 작성

완료 기준:

- Victoria UI에서 metrics를 조회할 수 있다.
- Victoria UI에서 logs를 조회할 수 있다.
- sample app trace를 조회할 수 있다.
- 핵심 alert rule이 동작한다.

---

## Phase 8. Backup / Restore

목표: 단일 master 구조의 한계를 backup/restore로 보완한다.

작업:

- [ ] OpenTofu state backup 정책 작성
- [ ] K3s snapshot 스크립트 작성
- [ ] K3s snapshot을 외부 저장소로 복사하는 방식 검토
- [ ] OpenBao backup 절차 작성
- [ ] OpenBao restore 절차 작성
- [ ] Victoria PVC backup 정책 작성
- [ ] restore drill 수행
- [ ] `docs/BACKUP_RESTORE.md` 작성
- [ ] `docs/DR_RUNBOOK.md` 작성

완료 기준:

- K3s snapshot이 생성된다.
- OpenBao backup 절차가 문서화되어 있다.
- 최소 1회 restore drill 결과가 기록되어 있다.

---

## Phase 9. CI Validation

목표: GitOps 반영 전 오류를 CI에서 차단한다.

작업:

- [ ] GitHub Actions CI workflow 작성
- [ ] tofu fmt/validate 추가
- [ ] ansible-lint 추가
- [ ] kustomize build 추가
- [ ] kubeconform 추가
- [ ] kyverno test 추가
- [ ] gitleaks 추가
- [ ] PR check 필수화 검토

완료 기준:

- PR에서 infra/ansible/k8s manifest 검증이 자동 수행된다.
- plaintext secret 유출이 CI에서 차단된다.

---

## Phase 10. 운영 성숙도 강화

목표: 운영형 플랫폼으로서의 문서와 절차를 보강한다.

작업:

- [ ] `docs/UPGRADE_STRATEGY.md` 작성
- [ ] `docs/INCIDENT_RESPONSE.md` 작성
- [ ] `docs/COST_MANAGEMENT.md` 작성
- [ ] 주요 alert별 runbook 작성
- [ ] Argo CD AppProject/RBAC 강화
- [ ] ApplicationSet PoC
- [ ] secret rotation runbook 작성
- [ ] NetworkPolicy 단계적 적용
- [ ] kube-bench 점검 검토

완료 기준:

- 주요 장애 상황별 runbook이 존재한다.
- upgrade 절차가 문서화되어 있다.
- incident response 흐름이 문서화되어 있다.

---

## 13. 우선순위 요약

### P0: 반드시 먼저 해야 할 일

- repo 구조 확정
- local Colima/K3s 재현
- OpenTofu OCI VM 생성
- Ansible K3s bootstrap
- Argo CD root app 구성
- local/oci-prod overlay 분리
- 기본 GitOps 배포 성공
- Git에 plaintext secret commit 금지
- K3s snapshot/backup 방향 수립

### P1: 안정화 단계

- KSOPS/SOPS 적용
- OpenBao single 배포
- ESO 연동
- Kyverno Audit policy
- VictoriaMetrics/VictoriaLogs 적용
- Victoria UI 노출
- CI validation
- backup/restore runbook

### P2: 성숙도 향상

- VictoriaTraces 적용
- VMAlert/Alertmanager 적용
- Reloader 적용
- Kyverno Enforce 확대
- NetworkPolicy 적용
- ApplicationSet PoC
- secret rotation
- restore drill
- upgrade strategy
- incident runbook

---

## 14. 성공 지표

### 14.1 기술적 성공 지표

- [ ] OpenTofu로 OCI VM 4대를 재생성할 수 있다.
- [ ] Ansible로 K3s 클러스터를 재설치할 수 있다.
- [ ] Argo CD root app으로 platform/apps를 배포할 수 있다.
- [ ] local과 oci-prod overlay가 분리되어 있다.
- [ ] Git에 plaintext secret이 없다.
- [ ] OpenBao secret이 Kubernetes Secret으로 동기화된다.
- [ ] Kyverno policy violation을 확인할 수 있다.
- [ ] Victoria UI에서 metrics/logs/traces를 조회할 수 있다.
- [ ] K3s snapshot을 생성하고 복구 절차를 문서화했다.
- [ ] CI에서 infra/ansible/k8s manifest 검증이 수행된다.

### 14.2 운영 성숙도 성공 지표

- [ ] 주요 장애 상황별 runbook이 있다.
- [ ] backup/restore drill을 수행했다.
- [ ] upgrade strategy가 문서화되어 있다.
- [ ] secret rotation 절차가 문서화되어 있다.
- [ ] alert가 runbook과 연결되어 있다.
- [ ] 비용 관리 문서가 있다.

---

## 15. 리스크 및 대응

| 리스크 | 영향 | 대응 |
|---|---|---|
| master 1c CPU 부족 | API/Argo CD 지연 | platform component requests/limits 최소화, 일반 app master 배치 제한 |
| single master 장애 | control-plane 중단 | K3s snapshot, restore runbook, master 재생성 자동화 |
| Observability 과부하 | worker CPU/memory pressure | Victoria Single mode, 짧은 retention, 단계적 적용 |
| OpenBao 장애 | runtime secret sync 실패 | backup/restore, unseal runbook, bootstrap secret 최소화 |
| Kyverno 과도한 Enforce | 배포 실패 | Audit-first, selected Enforce, exception 명시 |
| Secret 유출 | 보안 사고 | SOPS/KSOPS, gitleaks, plaintext secret 금지 |
| OpenTofu state 유실 | 인프라 관리 불가 | state backup, remote state 검토 |
| OCI Free Tier 제한 | 리소스 생성 실패 | resource sizing 보수화, LB/스토리지 사용 주의 |
| In-cluster CI 과부하 | 클러스터 성능 저하 | GitHub-hosted runner 사용 |

---

## 16. 권장 Makefile 명령

```makefile
TOFU ?= tofu
OCI_DIR := infra/oci/tofu
ANSIBLE_DIR := ansible
KUBECONFIG_OUT := $(HOME)/.kube/oci-k3s.yaml

oci-check:
	./infra/oci/scripts/oci-check.sh

infra-init:
	cd $(OCI_DIR) && $(TOFU) init

infra-plan:
	cd $(OCI_DIR) && $(TOFU) plan

infra-apply:
	cd $(OCI_DIR) && $(TOFU) apply

infra-destroy:
	cd $(OCI_DIR) && $(TOFU) destroy

inventory:
	cd $(OCI_DIR) && $(TOFU) output -json > ../oci-outputs.json
	./infra/oci/scripts/render-inventory.sh

ansible-ping:
	ansible -i $(ANSIBLE_DIR)/inventory/oci.ini all -m ping

k3s-install:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/site.yaml

kubeconfig:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/30-fetch-kubeconfig.yaml

argocd-bootstrap:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/40-bootstrap-argocd.yaml

oci-sync:
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl apply -f clusters/oci-prod/root-app.yaml

local-up:
	./bootstrap/local-colima/start.sh

local-down:
	./bootstrap/local-colima/stop.sh
```

---

## 17. 초기 MVP 범위

가장 먼저 완성해야 하는 MVP는 다음이다.

```text
MVP 목표:
  OCI VM 4대에 K3s 클러스터를 자동 구축하고,
  Argo CD로 app 하나와 platform 최소 구성 요소를 GitOps로 배포한다.

MVP 포함:
  - OpenTofu OCI VM 생성
  - Ansible K3s 설치
  - Argo CD bootstrap
  - local/oci-prod overlay
  - web-filesystem app 배포
  - KSOPS/SOPS 기본 적용
  - Kyverno Audit policy 1~2개
  - VictoriaMetrics 기본 monitoring

MVP 제외:
  - OpenBao runtime secret
  - VictoriaTraces
  - VMAlert/Alertmanager
  - ApplicationSet
  - NetworkPolicy enforce
  - restore drill
```

---

## 18. 최종 판단

현재 클러스터 제약에서는 다음 전략이 최적이다.

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

