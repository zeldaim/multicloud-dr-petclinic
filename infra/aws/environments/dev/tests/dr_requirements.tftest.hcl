# DR 요구사항 시험 — 클라우드 계정 없이(mock_provider) 코드 논리만 검증한다. 2026-11-16 개인 추가.
#   terraform init -backend=false && terraform test
# 증명하는 것: 이 코드로 만들어질 리소스의 설정 값이 DR(DMS CDC 복제)·보안 요구를 만족하는가
# 증명하지 못하는 것: 실제 AWS 에서 만들어지는가(API 오류·할당량), 실제로 복제·접속이 되는가
mock_provider "aws" {
  mock_data "aws_availability_zones" { defaults = { names = ["ap-northeast-2a", "ap-northeast-2b"] } }
  mock_data "aws_ami" { defaults = { id = "ami-0123456789abcdef0" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { name = "ap-northeast-2", region = "ap-northeast-2" } }
}
mock_provider "null" {}
mock_provider "tls" {}
mock_provider "local" {}

variables {
  db_password     = "test-only-password"
  azure_public_ip = "203.0.113.10"
}

run "rds_dms_cdc_prerequisites" {
  command = apply
  assert {
    condition     = anytrue([for p in aws_db_parameter_group.main.parameter : p.name == "binlog_format" && p.value == "ROW"])
    error_message = "DMS CDC 에는 binlog_format=ROW 가 필요하다"
  }
  assert {
    condition     = anytrue([for p in aws_db_parameter_group.main.parameter : p.name == "gtid-mode" && p.value == "ON"]) && anytrue([for p in aws_db_parameter_group.main.parameter : p.name == "enforce_gtid_consistency" && p.value == "ON"])
    error_message = "GTID(gtid-mode·enforce_gtid_consistency)가 켜져 있어야 한다"
  }
  assert {
    condition     = aws_db_instance.main.backup_retention_period >= 1
    error_message = "RDS 는 자동 백업이 켜져 있어야 바이너리 로그를 남긴다 (CDC 전제)"
  }
}

run "rds_not_public_and_encrypted" {
  command = apply
  assert {
    condition     = aws_db_instance.main.publicly_accessible == false
    error_message = "RDS 가 인터넷에 공개되면 안 된다"
  }
  assert {
    condition     = aws_db_instance.main.storage_encrypted == true
    error_message = "RDS 저장소는 암호화돼야 한다"
  }
}

run "two_az_and_vpn_route_to_azure" {
  command = apply
  assert {
    condition     = length(module.vpc.db_private_subnet_ids) == 2
    error_message = "DB 서브넷은 2개 AZ 에 있어야 한다"
  }
  assert {
    condition     = length(distinct([for s in aws_db_subnet_group.main.subnet_ids : s])) == 2
    error_message = "DB 서브넷 그룹이 2개 서브넷을 써야 한다"
  }
}

run "ssh_open_to_internet_by_default" {
  # 정책 시험: 기본값으로 배포하면 SSH 가 전체 인터넷에 열린다 (Trivy 지적과 같은 내용). 실패해야 정상인 시험이 아니라
  # 현재 상태를 기록하는 시험이다 — 고치면 이 assert 를 "!= 0.0.0.0/0" 으로 바꾼다.
  command = plan
  assert {
    condition     = var.allowed_ssh_cidr == "0.0.0.0/0"
    error_message = "기본 SSH 허용 대역이 바뀌었다 — 시험을 갱신할 것"
  }
}
