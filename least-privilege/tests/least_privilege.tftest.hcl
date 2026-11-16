# 최소 권한 시험 — 클라우드 계정 없이(mock_provider) 정책 문서의 내용만 검증한다.
#   terraform init -backend=false && terraform test
# 증명하는 것: 관리 서버의 평소 권한에 관리자·와일드카드 권한이 없고, 위험한 권한은 배포 역할로만 분리돼 있다
# 증명하지 못하는 것: 이 권한으로 서버 스크립트·eksctl 이 실제로 성공하는가 (실제 계정에서 확인 필요)
mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { name = "ap-northeast-2" } }
  mock_resource "aws_iam_policy" { defaults = { arn = "arn:aws:iam::123456789012:policy/mock-policy" } }
}

override_resource {
  target = aws_iam_role.mgmt_server
  values = { arn = "arn:aws:iam::123456789012:role/petclinic-mgmt-server-role" }
}
override_resource {
  target = aws_iam_role.mgmt_deployer
  values = { arn = "arn:aws:iam::123456789012:role/petclinic-mgmt-deployer" }
}

run "server_has_no_admin" {
  command = apply
  assert {
    condition     = !contains([aws_iam_role_policy_attachment.mgmt_daily.policy_arn, aws_iam_role_policy_attachment.mgmt_ssm_core.policy_arn], "arn:aws:iam::aws:policy/AdministratorAccess")
    error_message = "관리 서버 역할에 AdministratorAccess 가 붙어 있다"
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_policy.mgmt_daily.policy).Statement : alltrue([for a in flatten([s.Action]) : a != "*" && !endswith(a, ":*")])])
    error_message = "평소 권한에 '*' 또는 '서비스:*' 동작이 있다"
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_policy.mgmt_daily.policy).Statement : alltrue([for a in flatten([s.Action]) : !startswith(a, "iam:")])])
    error_message = "평소 권한에 IAM 동작이 있다 — IAM 은 배포 역할에서만"
  }
}

run "wildcard_resource_only_for_read" {
  command = apply
  assert {
    # Resource "*" 는 Describe/List(조회) 동작에만 허용
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.mgmt_daily.policy).Statement :
      alltrue([for a in flatten([s.Action]) : can(regex(":(Describe|List)", a))]) if s.Resource == "*"
    ])
    error_message = "조회가 아닌 동작에 Resource '*' 가 쓰였다"
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.mgmt_daily.policy).Statement :
      strcontains(s.Resource, ":parameter/petclinic/") && !endswith(s.Resource, ":parameter/*") if s.Sid == "ReadProjectParams"
    ])
    error_message = "SSM 읽기가 /petclinic/ 경로로 좁혀져 있지 않다"
  }
}

run "deployer_is_separated" {
  command = apply
  assert {
    condition     = one([for s in jsondecode(aws_iam_policy.mgmt_daily.policy).Statement : s.Resource if s.Sid == "SwitchToDeployer"]) == aws_iam_role.mgmt_deployer.arn
    error_message = "평소 역할이 넘겨받을 수 있는 역할은 배포 역할 하나여야 한다"
  }
  assert {
    condition     = jsondecode(aws_iam_role.mgmt_deployer.assume_role_policy).Statement[0].Principal.AWS == aws_iam_role.mgmt_server.arn
    error_message = "배포 역할은 관리 서버 역할만 넘겨받을 수 있어야 한다 (EC2·계정 전체 금지)"
  }
  assert {
    condition     = aws_iam_role.mgmt_deployer.max_session_duration <= 3600
    error_message = "배포 역할 임시 키는 1시간 이하여야 한다"
  }
}

run "deployer_iam_is_scoped" {
  command = apply
  assert {
    # iam:PassRole·CreateRole 등 쓰기 동작은 eksctl- 로 시작하는 리소스에만
    condition = alltrue([
      for r in flatten([jsondecode(aws_iam_policy.iam_limited_access.policy).Statement[0].Resource]) :
      can(regex("(eksctl-|oidc-provider/|AWSServiceRoleForAmazonEKSNodegroup)", r))
    ])
    error_message = "배포 역할의 IAM 쓰기 권한이 eksctl- 리소스 밖으로 열려 있다"
  }
  assert {
    condition     = jsondecode(aws_iam_policy.iam_limited_access.policy).Statement[2].Condition.StringEquals["iam:AWSServiceName"] == ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "eks-fargate.amazonaws.com"]
    error_message = "서비스 연결 역할 생성은 EKS 서비스로만 제한해야 한다"
  }
}
