# 관리 서버 최소 권한 — AdministratorAccess 를 역할에 맞는 정책으로

원래 프로젝트에서 관리 서버(eksctl·kubectl 를 돌리는 EC2)에는 `AdministratorAccess` 가 붙어 있었다
([`infra/aws/environments/dev/main.tf`](../infra/aws/environments/dev/main.tf) 87~89행).
LFD121(Developing Secure Software) 4장 "최소 권한 원칙"을 공부하며 이 부분을 다시 설계했다.
**기존 파일은 고치지 않았다.** 이 폴더는 대체안 + 시험 + 검증 기록이다. 참고 자료는 [`REFERENCES.md`](REFERENCES.md).

## 결과 요약

| | 기존 | 새 설계 |
|---|---|---|
| 서버가 항상 가진 권한 | 모든 동작 · 모든 리소스 (`*` / `*`) | SSM `/petclinic/*` 읽기, 서브넷·클러스터 조회, 배포 역할로 전환 |
| 클러스터 생성 권한 (EC2·CloudFormation·IAM) | 항상 있음 | **배포 역할**을 넘겨받을 때만, 임시 키 1시간 |
| IAM 쓰기 권한 | `iam:*` | 배포 역할에서만, `eksctl-*` 리소스로 한정 (eksctl 공식 최소 정책) |
| 서버가 탈취되면 | 계정 전체 | `/petclinic/` 설정값 읽기, 조회 |
| Checkov IAM 지적 | 3건 — **AdministratorAccess 사용(CKV_AWS_274)**, ESO 정책 `*` 리소스 2건 | 평소 역할 0건. 배포 역할의 `EksAllAccess`(eksctl 공식 정책 원문) 3건 |
| `terraform test` | — | 4/4 통과, 음성 시험 2건 실패 확인 |
| 동작 검증기 (AWS Service Reference 대조) | — | 43개 동작 ERROR 0. 내가 처음 `*` 로 둔 `eks:DescribeCluster` 를 잡아내 고침 |

## 구조

```
least-privilege/
  main.tf              평소 역할(mgmt_server) + 평소 정책(mgmt_daily) + 배포 역할(mgmt_deployer)
  eksctl_policies.tf   배포 역할에 붙는 eksctl 공식 최소 정책 4개
  variables.tf         project_name, ssm_path_prefix, deployer_session_seconds
  tests/               terraform test (mock) — 정책 문서 내용 시험
  verify/              check_actions.py — 동작 이름·범위를 AWS 공식 목록과 대조, fixtures/ = 일부러 틀린 정책
  results/             모든 실행 결과 원본
```

## 작업 과정 (순서대로)

### 1. 서버가 실제로 하는 일 → 필요한 권한

| 하는 일 | 근거 | 필요한 권한 |
|---|---|---|
| RDS 접속 정보 읽기 | `user_data_mgmt.sh` 125·126행 `aws ssm get-parameter --name /petclinic/prod/rds/...` | `ssm:GetParameter` — `/petclinic/` 아래만 |
| 서브넷 조회 | 같은 파일 204행 `aws ec2 describe-subnets` | `ec2:DescribeSubnets` |
| kubectl 접속 준비 | eksctl·kubectl 설치, `update-kubeconfig` | `eks:DescribeCluster`, `eks:ListClusters` |
| EKS 클러스터 만들기 | eksctl | EC2 · CloudFormation · EKS · 일부 IAM — **가끔만 필요** |

마지막 줄 때문에 `AdministratorAccess` 를 붙였던 것(main.tf 주석 "EKS 클러스터 생성 및 관리를 위해 필요"). → **평소 역할과 배포 역할로 나눈다.**

곁가지 발견: 서버 스크립트는 `/petclinic/prod/rds/endpoint` 를 읽는데 Terraform 이 만드는 파라미터는 `/petclinic/db_host` 다(`outputs_to_ssm.tf`). 경로가 다르다 — 새 정책은 `/petclinic/*` 라 둘 다 허용하지만 원래 코드의 불일치로 기록.

### 2. 정책 작성

- 평소 정책([`main.tf`](main.tf)): 문장(Statement) 4개 — SSM 읽기(`/petclinic/*`), 조회(`*` — 대상 지정을 지원하지 않는 동작만), 프로젝트 클러스터 조회, 배포 역할 전환.
- 배포 역할: 신뢰 정책의 Principal 을 **평소 역할 하나**로 제한, `max_session_duration = 3600`.
- 배포 역할 정책([`eksctl_policies.tf`](eksctl_policies.tf)): eksctl 공식 문서 원문. 직접 만든 권한이 아니라 출처가 있는 권한이다.

### 3. 시험 — `terraform test` + mock (계정 없이)

| 시험(run) | 확인 |
|---|---|
| `server_has_no_admin` | 평소 역할에 AdministratorAccess 없음, `*`·`서비스:*` 동작 없음, IAM 동작 없음 |
| `wildcard_resource_only_for_read` | Resource `*` 는 Describe/List 에만, SSM 은 `/petclinic/` 로 한정 |
| `deployer_is_separated` | 평소 역할이 넘겨받을 수 있는 건 배포 역할 하나, 배포 역할은 평소 역할만 넘겨받음, 임시 키 ≤ 1시간 |
| `deployer_iam_is_scoped` | 배포 역할의 IAM 쓰기는 `eksctl-*` 리소스만, 서비스 연결 역할은 EKS 만 |

결과 [`results/test.txt`](results/test.txt): `Success! 4 passed, 0 failed.`

**음성 시험** — 일부러 틀리게 하면 실패해야 한다:

| 바꾼 값 | 실패한 시험 | 결과 |
|---|---|---|
| `-var ssm_path_prefix=/` (SSM 전체 읽기) | `wildcard_resource_only_for_read` — "SSM 읽기가 /petclinic/ 경로로 좁혀져 있지 않다" | [`results/test_negative_ssm_all.txt`](results/test_negative_ssm_all.txt) |
| `-var deployer_session_seconds=43200` (12시간) | `deployer_is_separated` — "배포 역할 임시 키는 1시간 이하여야 한다" | [`results/test_negative_session.txt`](results/test_negative_session.txt) |

### 4. 검증기 — 동작 이름이 진짜인가, 범위를 더 좁힐 수 있나

정책은 사람이든 AI 든 틀리게 쓸 수 있다(없는 동작 이름, 대상 지정이 안 되는 동작에 ARN 지정). AWS 가 공개하는 기계 판독용 목록(Service Reference)과 대조하는 [`verify/check_actions.py`](verify/check_actions.py) 를 만들었다.

| 규칙 | 뜻 |
|---|---|
| E1 | 존재하지 않는 동작 — 정책이 아무 효과 없음 |
| E2 | 대상 지정을 지원하지 않는 동작에 ARN 지정 — 실제로 허용되지 않음 |
| W1 | Resource `*` 인데 대상 지정 가능 — 더 좁힐 수 있음 |
| W2 | 권한 관리 동작 — 어느 역할에 있는지 사람이 확인 |

1) **검증기 자체 시험**: 일부러 틀린 정책 [`verify/fixtures/bad_policy.tf`](verify/fixtures/bad_policy.tf) → E1·E2·W1 모두 잡음, 종료 코드 1 ([`results/verify_actions_negative_fixture.md`](results/verify_actions_negative_fixture.md)).
   - 처음엔 한 줄로 쓴 문장의 Resource 를 잘못 읽어 W1 을 놓쳤다 → 파서 수정 후 재실행.
2) **내 정책 검증**: 처음 판에서 `eks:DescribeCluster` 를 "조회라 대상 지정이 안 된다"고 `*` 로 뒀는데, 검증기가 **W1 (cluster 리소스로 좁힐 수 있음)** 으로 잡았다. → `cluster/petclinic*` 로 좁혀 별도 문장으로 분리.
3) 최종 [`results/verify_actions.md`](results/verify_actions.md): 동작 43개, **ERROR 0**. 남은 경고는 모두 배포 역할의 eksctl 공식 정책(kms·logs `*`, IAM 권한 관리 동작) — 좁힐 여지는 있으나 출처 원문 유지.

### 5. 정책 점검 도구 비교 — Checkov 3.4.5

| 대상 | IAM 관련 지적 |
|---|---|
| 기존 `infra/aws/environments/dev` | `CKV_AWS_274` AdministratorAccess 사용 · `CKV_AWS_355`/`CKV_AWS_288` ESO 정책 `*` 리소스 |
| 새 `least-privilege` | 평소 역할 **0건**. `eks_all_access`(eksctl 공식 `eks:*`) 3건 |

원본: [`results/checkov_infra_aws_environments_dev.json`](results/checkov_infra_aws_environments_dev.json), [`results/checkov_least-privilege.json`](results/checkov_least-privilege.json)

참고: 전날 Trivy 0.57.1 점검([`tf-local/`](../tf-local/README.md))은 AdministratorAccess 연결을 지적하지 않았다. Checkov 는 지적했다 — 도구마다 규칙이 다르므로 하나만 믿지 않는다.

## 따라 하기

레포 루트, Git Bash 기준.

```bash
export MSYS_NO_PATHCONV=1
TF="docker run --rm -v $(pwd):/w hashicorp/terraform:1.10.5"

$TF -chdir=/w/least-privilege init -backend=false
$TF -chdir=/w/least-privilege test
# 예상: Success! 4 passed, 0 failed.

$TF -chdir=/w/least-privilege test -var ssm_path_prefix=/
# 예상: run "wildcard_resource_only_for_read"... fail / Failure! 3 passed, 1 failed.

cd least-privilege
python verify/check_actions.py main.tf eksctl_policies.tf --offline
# 예상 마지막 줄: ERROR 0 / 동작 43 -> results/verify_actions.md

python verify/check_actions.py verify/fixtures/bad_policy.tf --offline --out=verify_actions_negative_fixture.md; echo $?
# 예상: E1 ... E2 ... W1 ... / ERROR 2 / 1
cd ..

docker run --rm -v $(pwd):/w bridgecrew/checkov:3.4.5 -d /w/least-privilege --framework terraform --compact --quiet --skip-path verify/fixtures
```

## 한계

- **mock 시험과 검증기는 정책 문서만 본다.** 이 권한으로 서버 스크립트와 eksctl 이 실제로 성공하는지는 실제 계정에서 확인해야 한다.
- 배포 역할의 `AmazonEC2FullAccess` 는 여전히 넓다. 더 줄이려면 실제 계정에서 eksctl 을 한 번 돌리고 CloudTrail + IAM Access Analyzer 정책 생성으로 "실제로 쓴 권한"만 남겨야 한다.
- SSM SecureString 복호화에 `kms:Decrypt` 가 필요 없다는 판단(AWS 관리 키 aws/ssm 사용 가정)은 미확인.
- ESO 정책(`external_secrets_policy`, `Resource = "*"`)은 이번 범위에서 고치지 않았다.
- 검증기는 .tf 를 가볍게 파싱한다. AWS 관리 정책 내용과 Condition 은 검사하지 않는다.
