# eksctl 공식 "Minimum IAM policies" (https://docs.aws.amazon.com/eks/latest/eksctl/minimum-iam-policies.html, 2026-11-17 확인)
# AmazonEC2FullAccess · AWSCloudFormationFullAccess (AWS 관리) + EksAllAccess · IamLimitedAccess (문서 JSON, 계정 번호만 치환)
# 배포 역할에만 붙인다. AmazonEC2FullAccess 는 여전히 넓다 — 더 줄이려면 실제 계정에서 CloudTrail + Access Analyzer 정책 생성이 필요.

resource "aws_iam_role_policy_attachment" "deployer_ec2" {
  role       = aws_iam_role.mgmt_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "deployer_cfn" {
  role       = aws_iam_role.mgmt_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

resource "aws_iam_policy" "eks_all_access" {
  name = "${var.project_name}-EksAllAccess"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "eks:*", Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = ["arn:aws:ssm:*:${local.acct}:parameter/aws/*", "arn:aws:ssm:*::parameter/aws/*"]
      },
      { Effect = "Allow", Action = ["kms:CreateGrant", "kms:DescribeKey"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:PutRetentionPolicy"], Resource = "*" }
    ]
  })
}

resource "aws_iam_policy" "iam_limited_access" {
  name = "${var.project_name}-IamLimitedAccess"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile", "iam:GetRole", "iam:CreateRole", "iam:DeleteRole",
          "iam:AttachRolePolicy", "iam:PutRolePolicy", "iam:UpdateAssumeRolePolicy",
          "iam:AddRoleToInstanceProfile", "iam:ListInstanceProfilesForRole", "iam:PassRole",
          "iam:DetachRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
          "iam:ListAttachedRolePolicies", "iam:TagRole", "iam:UntagRole", "iam:GetPolicy",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:ListPolicyVersions"
        ]
        Resource = [
          "arn:aws:iam::${local.acct}:instance-profile/eksctl-*",
          "arn:aws:iam::${local.acct}:role/eksctl-*",
          "arn:aws:iam::${local.acct}:policy/eksctl-*",
          "arn:aws:iam::${local.acct}:oidc-provider/*",
          "arn:aws:iam::${local.acct}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
          "arn:aws:iam::${local.acct}:role/eksctl-managed-*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:GetUser"]
        Resource = ["arn:aws:iam::${local.acct}:role/*", "arn:aws:iam::${local.acct}:user/*"]
      },
      {
        Effect    = "Allow"
        Action    = ["iam:CreateServiceLinkedRole"]
        Resource  = "*"
        Condition = { StringEquals = { "iam:AWSServiceName" = ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "eks-fargate.amazonaws.com"] } }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deployer_eks" {
  role       = aws_iam_role.mgmt_deployer.name
  policy_arn = aws_iam_policy.eks_all_access.arn
}

resource "aws_iam_role_policy_attachment" "deployer_iam" {
  role       = aws_iam_role.mgmt_deployer.name
  policy_arn = aws_iam_policy.iam_limited_access.arn
}
