# Terraform 로컬 검증 — 클라우드 계정 없이 인프라 코드 확인

원래 프로젝트의 Terraform(`infra/aws/environments/dev`, `infra/azure`)을 **실제 배포 없이** 확인한 기록이다.
기존 `.tf` 파일은 고치지 않았다. 새로 만든 것은 시험 파일 두 개와 `results/` 의 실행 결과뿐이다.

## 무엇을 증명하고, 무엇을 못 하는가

| 단계 | 도구 | 증명하는 것 | 증명하지 못하는 것 | 결과 |
|---|---|---|---|---|
| 1. 문법 | `terraform validate`, `fmt -check` | 코드가 문법·타입상 올바르다 | 리소스가 실제로 만들어지는가 | AWS·Azure 통과. AWS fmt 불일치 3파일, Azure `enable_bgp` deprecated 경고 |
| 2. 설정 점검 | Trivy `config` | 알려진 잘못된 보안 설정이 있는가 | 그 설정이 이 구조에서 실제로 위험한가(판단은 사람) | HIGH·CRITICAL 11건 |
| 3. 요구사항 시험 | `terraform test` + `mock_provider` | 만들어질 리소스의 **설정 값**이 DR·보안 요구를 만족한다 | API 오류·할당량, VPN 터널 연결, 실제 복제 | AWS 4/4, Azure 4/4 통과 |
| 4. 시험이 실패할 수 있는가 | 값을 틀리게 바꿔 재실행 | 시험이 항상 통과하는 빈 시험이 아니다 | — | AWS 1 fail, Azure 1 fail (의도한 assert) |

## 찾은 것

- **SSH 가 인터넷 전체에 열림** — AWS bastion SG(`allowed_ssh_cidr` 기본값 `0.0.0.0/0`), Azure VM NSG(`source_address_prefix = "*"`). Trivy 와 시험 양쪽에서 확인.
- **무제한 egress 6건, 공개 서브넷 public IP 자동 할당 2건** (Trivy).
- **Azure MySQL `require_secure_transport=OFF`** — 앱의 azure 프로필은 `useSSL=true` 로 접속한다. 둘 중 하나가 문서와 다르게 동작했을 가능성이 있어 기록만 했다.
- **Azure DB 이름 `petclinic-dr-db`** — 앱이 기대하는 이름은 `petclinic`. DMS/덤프가 스키마를 새로 만들면 문제없지만 확인이 필요하다.
- DB 쪽은 요구를 만족한다: AWS RDS binlog ROW·GTID·백업, 비공개·암호화, 2개 AZ / Azure MySQL GTID ON, 위임 서브넷, DB NSG 는 VNet·AWS VPC 대역만 3306 허용.

## 시험 파일

| 파일 | 시험(run) |
|---|---|
| [`infra/aws/environments/dev/tests/dr_requirements.tftest.hcl`](../infra/aws/environments/dev/tests/dr_requirements.tftest.hcl) | DMS CDC 전제(binlog ROW·GTID·백업≥1) · RDS 비공개·암호화 · DB 서브넷 2 AZ · SSH 기본값 기록 |
| [`infra/azure/tests/dr_requirements.tftest.hcl`](../infra/azure/tests/dr_requirements.tftest.hcl) | 복제 대상 조건(GTID·8.0) · DB 비공개(위임 서브넷·NSG) · IPsec VPN 과 대역 겹침 계산 · 현재 상태 기록(SSL OFF·SSH·DB 이름) |

"현재 상태 기록" 시험은 정책을 강제하는 시험이 아니라 지금 값을 적어 둔 것이다. 값이 바뀌면 실패해서 다시 확인하게 만든다.

mock 을 쓰면서 겪은 것:
- azurerm 은 리소스 ID 형식을 검사한다 → 타입별로 형식에 맞는 가짜 ID 를 `mock_resource` 로 줬다. 서브넷은 `override_resource` 로 서로 다른 ID 를 줘야 "DB 가 DB 서브넷에 있다"는 비교가 의미 있다.
- azurerm 은 비밀번호 복잡도와 SSH 공개키 형식도 검사한다 → 시험 값도 규칙에 맞게, 공개키는 버린 키의 공개키(`infra/azure/tests/fixtures/test_key.pub`).
- 시험 파일 안의 `variables` 가 CLI `-var` 보다 우선한다 → Azure 음성 시험은 값을 바꾼 임시 사본으로 돌렸다.

## 따라 하기

Docker 만 있으면 된다. Windows Git Bash 기준, 레포 루트에서 실행한다.

```bash
export MSYS_NO_PATHCONV=1
TF="docker run --rm -v $(pwd):/w hashicorp/terraform:1.10.5"
```

**1) AWS 시험**

```bash
$TF -chdir=/w/infra/aws/environments/dev init -backend=false
$TF -chdir=/w/infra/aws/environments/dev test
```

예상 출력 마지막 줄:
```
Success! 4 passed, 0 failed.
```

**2) AWS 음성 시험** — 백업을 끄면 CDC 전제 시험이 실패해야 한다

```bash
$TF -chdir=/w/infra/aws/environments/dev test -var db_backup_retention_period=0
```

예상:
```
  run "rds_dms_cdc_prerequisites"... fail
RDS 는 자동 백업이 켜져 있어야 바이너리 로그를 남긴다 (CDC 전제)
Failure! 3 passed, 1 failed.
```

**3) Azure 시험**

```bash
$TF -chdir=/w/infra/azure init -backend=false
$TF -chdir=/w/infra/azure test
```

예상:
```
Success! 4 passed, 0 failed.
```

**4) Azure 음성 시험** — AWS 대역을 Azure VNet 과 겹치게 한 사본

```bash
sed 's#"10.0.0.0/16"#"192.168.0.0/20"#' infra/azure/tests/dr_requirements.tftest.hcl > infra/azure/tests/zz_neg.tftest.hcl
$TF -chdir=/w/infra/azure test -filter=tests/zz_neg.tftest.hcl
rm infra/azure/tests/zz_neg.tftest.hcl
```

예상:
```
  run "site_to_site_vpn_to_aws"... fail
Azure VNet 과 AWS VPC 대역이 겹치면 VPN 라우팅이 안 된다
Failure! 3 passed, 1 failed.
```

**5) Trivy 설정 점검**

```bash
docker run --rm -v $(pwd):/w aquasec/trivy:0.57.1 config --severity HIGH,CRITICAL /w/infra
```

예상 (파일 3개, 합계 11건):
```
Failures: 5 (HIGH: 1, CRITICAL: 4)    ← aws/modules/security-groups/main.tf
Failures: 4 (HIGH: 2, CRITICAL: 2)    ← aws/modules/vpc/main.tf
Failures: 2 (HIGH: 0, CRITICAL: 2)    ← azure/bastion.tf
```

## 결과 파일

| 파일 | 내용 |
|---|---|
| `results/validate_*.txt` | fmt·init·validate 출력 |
| `results/trivy_config.json` | Trivy 원본 결과 |
| `results/test_aws.txt`, `results/test_azure.txt` | 시험 통과 출력 |
| `results/test_aws_negative_backup0.txt`, `results/test_azure_negative_overlap.txt` | 음성 시험 출력 |
