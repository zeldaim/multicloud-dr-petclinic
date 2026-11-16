# 동작(Action) 검증 결과 — AWS Service Reference 대조

서비스 데이터 버전(modified, epoch): ec2=v1.5, s3=v1.5

| 파일 | 행 | Sid | 동작 | 일치 수 | 판정 |
|---|---|---|---|---|---|
| bad_policy.tf | 5 | Typo | ec2:DescribeSubnetz | 0 | E1 존재하지 않는 동작 |
| bad_policy.tf | 6 | ArnOnUnscoped | ec2:DescribeSubnets | 1 | E2 대상 지정 불가인데 ARN 지정 |
| bad_policy.tf | 7 | StarOnScoped | s3:GetObject | 1 | W1 '*' 대신 좁힐 수 있음: accesspointobject, object |

ERROR 2건, 검사한 동작 3개
