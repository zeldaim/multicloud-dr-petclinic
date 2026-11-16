# 검증기 음성 시험용 — 일부러 틀린 정책 (배포하지 않음)
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Statement = [
      { Sid = "Typo", Effect = "Allow", Action = ["ec2:DescribeSubnetz"], Resource = "*" },
      { Sid = "ArnOnUnscoped", Effect = "Allow", Action = ["ec2:DescribeSubnets"], Resource = "arn:aws:ec2:ap-northeast-2:123456789012:subnet/subnet-1" },
      { Sid = "StarOnScoped", Effect = "Allow", Action = ["s3:GetObject"], Resource = "*" }
    ]
  })
}
