# 관리 서버 최소 권한안 — infra/aws/environments/dev/main.tf 62~89행(AdministratorAccess)을 대체하는 설계.
# 기존 파일은 고치지 않고 별도 모듈로 둔다. 근거: user_data_mgmt.sh 가 실제로 하는 일.
#
#   평소 역할(mgmt_server)  : 서버에 항상 붙음. SSM 읽기 + 조회 + 배포 역할로 전환만 가능
#   배포 역할(mgmt_deployer): eksctl 로 클러스터를 만들 때만 넘겨받음 (임시 키, 기본 1시간)

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  acct   = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

# ---------------------------------------------------------------------------
# 평소 역할 — 신뢰 정책은 기존과 같다 (EC2 만 이 역할을 쓴다)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "mgmt_server" {
  name = "${var.project_name}-mgmt-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "mgmt_daily" {
  name        = "${var.project_name}-mgmt-daily"
  description = "관리 서버 평소 권한: SSM 읽기, 조회, 배포 역할 전환"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # user_data_mgmt.sh 125·126행 — RDS 접속 정보. SecureString 은 AWS 관리 키(aws/ssm)라 kms:Decrypt 를 따로 주지 않는다
        Sid      = "ReadProjectParams"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${local.region}:${local.acct}:parameter${var.ssm_path_prefix}*"
      },
      {
        # user_data_mgmt.sh 204행 — 서브넷 조회 / 클러스터 목록
        # 이 두 동작은 대상(리소스) 지정을 지원하지 않아 "*" 만 가능 (verify/check_actions.py 로 Service Reference 대조)
        Sid      = "ReadOnlyList"
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets", "eks:ListClusters"]
        Resource = "*"
      },
      {
        # kubectl 접속 준비(aws eks update-kubeconfig) — DescribeCluster 는 cluster 리소스 지정을 지원하므로 프로젝트 클러스터로 좁힌다
        # (처음엔 "*" 로 뒀다가 검증기 W1 로 발견해 고침)
        Sid      = "DescribeProjectCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${local.region}:${local.acct}:cluster/${var.project_name}*"
      },
      {
        Sid      = "SwitchToDeployer"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.mgmt_deployer.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mgmt_daily" {
  role       = aws_iam_role.mgmt_server.name
  policy_arn = aws_iam_policy.mgmt_daily.arn
}

# 세션 관리자(SSM) 접속용 — 기존 서버가 SSM 으로 접속하는 경우에만 필요한 AWS 관리 정책
resource "aws_iam_role_policy_attachment" "mgmt_ssm_core" {
  role       = aws_iam_role.mgmt_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "mgmt_server" {
  name = "${var.project_name}-mgmt-server-profile"
  role = aws_iam_role.mgmt_server.name
}

# ---------------------------------------------------------------------------
# 배포 역할 — 평소 역할만 넘겨받을 수 있고, 임시 키는 짧게 만료
# ---------------------------------------------------------------------------
resource "aws_iam_role" "mgmt_deployer" {
  name                 = "${var.project_name}-mgmt-deployer"
  max_session_duration = var.deployer_session_seconds
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${local.acct}:role/${var.project_name}-mgmt-server-role" }
    }]
  })
}
