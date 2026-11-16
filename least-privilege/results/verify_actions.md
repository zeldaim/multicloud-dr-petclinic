# 동작(Action) 검증 결과 — AWS Service Reference 대조

서비스 데이터 버전(modified, epoch): ec2=v1.5, eks=v1.5, iam=v1.5, kms=v1.5, logs=v1.5, ssm=v1.5, sts=v1.5

| 파일 | 행 | Sid | 동작 | 일치 수 | 판정 |
|---|---|---|---|---|---|
| main.tf | 40 | ReadProjectParams | ssm:GetParameter | 1 | OK |
| main.tf | 40 | ReadProjectParams | ssm:GetParameters | 1 | OK |
| main.tf | 40 | ReadProjectParams | ssm:GetParametersByPath | 1 | OK |
| main.tf | 48 | ReadOnlyList | ec2:DescribeSubnets | 1 | OK |
| main.tf | 48 | ReadOnlyList | eks:ListClusters | 1 | OK |
| main.tf | 56 | DescribeProjectCluster | eks:DescribeCluster | 1 | OK |
| main.tf | 62 | SwitchToDeployer | sts:AssumeRole | 1 | OK |
| eksctl_policies.tf | 20 | - | eks:* | 74 | OK |
| eksctl_policies.tf | 23 | - | ssm:GetParameter | 1 | OK |
| eksctl_policies.tf | 23 | - | ssm:GetParameters | 1 | OK |
| eksctl_policies.tf | 26 | - | kms:CreateGrant | 1 | W1 '*' 대신 좁힐 수 있음: key; W2 권한 관리 동작 |
| eksctl_policies.tf | 26 | - | kms:DescribeKey | 1 | W1 '*' 대신 좁힐 수 있음: key |
| eksctl_policies.tf | 27 | - | logs:PutRetentionPolicy | 1 | W1 '*' 대신 좁힐 수 있음: log-group |
| eksctl_policies.tf | 39 | - | iam:CreateInstanceProfile | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:DeleteInstanceProfile | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:GetInstanceProfile | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:RemoveRoleFromInstanceProfile | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:GetRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:CreateRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:DeleteRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:AttachRolePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:PutRolePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:UpdateAssumeRolePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:AddRoleToInstanceProfile | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:ListInstanceProfilesForRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:PassRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:DetachRolePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:DeleteRolePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:GetRolePolicy | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:GetOpenIDConnectProvider | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:CreateOpenIDConnectProvider | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:DeleteOpenIDConnectProvider | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:TagOpenIDConnectProvider | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:ListAttachedRolePolicies | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:TagRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:UntagRole | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:GetPolicy | 1 | OK |
| eksctl_policies.tf | 39 | - | iam:CreatePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:DeletePolicy | 1 | W2 권한 관리 동작 |
| eksctl_policies.tf | 39 | - | iam:ListPolicyVersions | 1 | OK |
| eksctl_policies.tf | 61 | - | iam:GetRole | 1 | OK |
| eksctl_policies.tf | 61 | - | iam:GetUser | 1 | OK |
| eksctl_policies.tf | 66 | - | iam:CreateServiceLinkedRole | 1 | W1 '*' 대신 좁힐 수 있음: role |

ERROR 0건, 검사한 동작 43개
