# 참고 자료

이 폴더를 만들면서 실제로 본 자료와, 이름만 언급하고 직접 확인하지 않은 자료를 나눠 적는다. 확인 날짜는 2026-11-17.

## 1. 직접 열어 보고 내용을 쓴 자료

| 자료 | 어디에 썼나 | 
|---|---|
| eksctl **Minimum IAM policies** — https://docs.aws.amazon.com/eks/latest/eksctl/minimum-iam-policies.html (eksctl.io 에서 이 주소로 이동됨) | `eksctl_policies.tf` — 배포 역할 정책 4개(AmazonEC2FullAccess, AWSCloudFormationFullAccess, EksAllAccess, IamLimitedAccess). JSON 은 계정 번호만 바꿔 옮김 | 
| AWS **Service Reference** (기계 판독용 동작·리소스 목록) — https://servicereference.us-east-1.amazonaws.com/ , 서비스별 `https://servicereference.us-east-1.amazonaws.com/v1/<서비스>/<서비스>.json` | `verify/check_actions.py` — 동작 존재 여부, 대상 지정 가능 여부, 권한 관리 동작 여부. 사본: `results/service_reference/` (v1.5, ec2·eks·iam·kms·logs·s3·ssm·sts) | 
| **이 레포 코드** — `infra/aws/environments/dev/main.tf` 62~89행(관리 서버 역할 + AdministratorAccess), 105~125행(ESO 정책), `user_data_mgmt.sh` 125·126·204행, `outputs_to_ssm.tf` | 관리 서버가 실제로 하는 일 → 필요한 권한 목록 | 
| 내 노트 — **LFD121 Chapter 4. Secure Design Principles** (최소 권한) | 이 작업의 출발점: "관리 서버의 AdministratorAccess 를 역할에 맞는 정책으로 바꿔야 한다" |

## 2. 도구 (버전 고정)

| 도구 | 버전 | 용도 |
|---|---|---|
| Terraform | 1.10.5 (Docker `hashicorp/terraform:1.10.5`) | `fmt`, `terraform test` + `mock_provider` |
| Checkov | 3.4.5 (Docker `bridgecrew/checkov:3.4.5`) | 기존 정책 vs 새 정책 정책 점검 비교 |
| Python | 3.x 표준 라이브러리만 | `verify/check_actions.py` |

## 3. 참고 자료

| 자료 |
|---|
| AWS Service Authorization Reference |
| IAM Access Analyzer — 정책 검증(validate-policy), CloudTrail 기반 정책 생성 | 실제 계정이 있을 때 다음 단계 |
| AWS 관리 정책 원문 (AdministratorAccess, AmazonEC2FullAccess, AWSCloudFormationFullAccess, AmazonSSMManagedInstanceCore) | 
| SSM SecureString 과 AWS 관리 키(aws/ssm) 의 kms:Decrypt 필요 여부 | `main.tf` 주석에 "따로 주지 않는다"고 적음 — **미확인, 실제 계정에서 확인 필요** |
| Terraform `terraform test` · `mock_provider` 공식 문서 | 문서 대신 실행 결과로 동작 확인 |
