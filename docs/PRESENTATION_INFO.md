# PetClinic Test Infrastructure - 발표자료 정보

## 📋 프로젝트 개요

### 프로젝트명
**PetClinic Test Infrastructure** - Spring PetClinic MSA 애플리케이션을 위한 AWS 프로덕션 인프라

### 목적
- Spring PetClinic MSA 애플리케이션을 위한 완전한 AWS 인프라 구축
- Terraform을 사용한 Infrastructure as Code (IaC) 구현
- 고가용성, 보안, 확장성을 고려한 아키텍처 설계
- 디렉터리 기반 환경 격리 구조로 리팩토링 완료

---

## 🏗️ 아키텍처 개요

### 네트워크 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└───────────────────────┬─────────────────────────────────────┘
                        │
            ┌───────────▼───────────┐
            │   Internet Gateway   │
            └───────────┬───────────┘
                        │
        ┌───────────────┴───────────────┐
        │      VPC (10.0.0.0/16)        │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  Public Subnet A        │ │
        │  │  (10.0.0.0/25)          │ │
        │  │  - Bastion Host         │ │
        │  │  - NAT Gateway (Regional)│ │
        │  └─────────────────────────┘ │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  Public Subnet B        │ │
        │  │  (10.0.10.0/25)         │ │
        │  │  - ALB (예정)           │ │
        │  └─────────────────────────┘ │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  App Private Subnet A    │ │
        │  │  (10.0.0.128/25)        │ │
        │  │  - Management Server    │ │
        │  │  - EKS Nodes (예정)     │ │
        │  └─────────────────────────┘ │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  App Private Subnet B   │ │
        │  │  (10.0.10.128/25)       │ │
        │  │  - EKS Nodes (예정)     │ │
        │  └─────────────────────────┘ │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  DB Private Subnet A    │ │
        │  │  (10.0.1.0/25)          │ │
        │  │  - RDS MySQL            │ │
        │  └─────────────────────────┘ │
        │                               │
        │  ┌─────────────────────────┐ │
        │  │  DB Private Subnet B    │ │
        │  │  (10.0.11.0/25)         │ │
        │  │  - RDS MySQL (Standby)  │ │
        │  └─────────────────────────┘ │
        └───────────────────────────────┘
```

### 주요 특징
- **고가용성**: 2개 AZ 사용, Regional NAT Gateway
- **보안**: Private Subnet 배치, Security Group 최소 권한
- **확장성**: EKS 클러스터 준비 (eksctl로 생성 예정)
- **하이브리드 클라우드**: Azure VPN 연결 지원

---

## 📦 주요 구성 요소

### 1. 네트워크 (VPC Module)

#### VPC
- **CIDR**: `10.0.0.0/16`
- **DNS**: Hostnames 및 Support 활성화
- **가용 영역**: 2개 (ap-northeast-2a, ap-northeast-2b)

#### 서브넷 구성
| 타입 | CIDR | 용도 | 개수 |
|------|------|------|------|
| Public | 10.0.0.0/25, 10.0.10.0/25 | Bastion, NAT Gateway, ALB | 2 |
| App Private | 10.0.0.128/25, 10.0.10.128/25 | Management Server, EKS Nodes | 2 |
| DB Private | 10.0.1.0/25, 10.0.11.0/25 | RDS MySQL | 2 |

#### NAT Gateway
- **타입**: Regional NAT Gateway (자동 확장)
- **고가용성**: Regional 모드로 자동 장애 조치
- **비용 최적화**: 단일 Regional NAT Gateway 사용

#### 라우팅
- **Public Route Table**: Internet Gateway로 라우팅
- **App Private Route Tables**: Regional NAT Gateway로 라우팅 (각 AZ별)
- **DB Private Route Tables**: Regional NAT Gateway로 라우팅 (각 AZ별)

#### Azure VPN 연결
- **VPN Gateway**: AWS VPC와 Azure VNet 간 연결
- **Customer Gateway**: Azure VPN Gateway 연결
- **Static Routes**: Azure CIDR (192.168.0.0/16) 라우팅
- **Route 53 Resolver**: Azure Private DNS Resolver 연동

---

### 2. 컴퓨팅 (EC2 Module)

#### Bastion Host
- **인스턴스 타입**: t3.micro
- **위치**: Public Subnet A
- **용도**: SSH 접근 게이트웨이
- **보안**: 
  - IMDSv2 강제
  - Security Group으로 SSH 접근 제한
  - Public IP 할당

#### Management Server
- **인스턴스 타입**: t3.medium
- **위치**: App Private Subnet A
- **용도**: 
  - EKS 클러스터 관리 (eksctl, kubectl)
  - RDS 초기화 및 관리
  - CI/CD 파이프라인 실행
- **설치 도구**:
  - AWS CLI v2
  - kubectl
  - eksctl
  - Helm
  - Docker
  - MySQL Client
  - k9s (Kubernetes TUI)
- **IAM**: AdministratorAccess (EKS 클러스터 생성용)
- **보안**: 
  - IMDSv2 강제
  - Bastion을 통해서만 SSH 접근 가능

#### SSH 키 관리
- **자동 생성**: TLS Provider로 RSA 4096bit 키 생성
- **저장 위치**: `environments/dev/mykey/`
- **권한**: 0400 (소유자만 읽기)

---

### 3. 데이터베이스 (RDS)

#### RDS MySQL 8.0
- **인스턴스 클래스**: db.t3.small
- **스토리지**: 
  - 초기: 20GB
  - 최대: 40GB (자동 스케일링)
  - 타입: gp3
  - 암호화: 활성화
- **네트워크**: 
  - DB Private Subnet에 배치
  - Public 접근 불가
  - Security Group으로 접근 제어
- **고가용성**: 
  - Multi-AZ: false (현재), true (예정)
  - 백업 보관: 7일
- **파라미터 그룹**:
  - Character Set: utf8mb4
  - GTID 모드: 활성화
  - Binlog 형식: ROW
  - Max Connections: 200

#### 데이터베이스 구조 (MSA)
- **customers_db**: 고객 및 애완동물 정보
- **vets_db**: 수의사 정보
- **visits_db**: 방문 기록
- **사용자**: 각 서비스별 전용 사용자 (customers_user, vets_user, visits_user)

---

### 4. 보안 (Security Groups Module)

#### Security Group 구성

| Security Group | Ingress | Egress | 용도 |
|----------------|---------|--------|------|
| Bastion | SSH (22) from allowed CIDR | All | Bastion Host |
| Management | SSH (22) from Bastion SG | All | Management Server |
| RDS | MySQL (3306) from Mgmt SG + App Private Subnets | All | RDS MySQL |
| EKS Cluster | HTTPS (443) from VPC, Internal | All | EKS 클러스터 (예정) |

#### 보안 원칙
- **최소 권한 원칙**: 필요한 포트만 열기
- **Security Group 참조**: IP 대신 Security Group ID 사용
- **Private Subnet**: 데이터베이스는 Private Subnet에만 배치

---

### 5. IAM (Identity and Access Management)

#### Management Server IAM Role
- **역할**: `petclinic-mgmt-server-role`
- **정책**: AdministratorAccess (EKS 클러스터 생성용)
- **Instance Profile**: EC2 인스턴스에 연결

#### External Secrets Operator Policy
- **용도**: EKS에서 Secrets Manager 및 SSM Parameter 읽기
- **권한**: 
  - `secretsmanager:GetSecretValue`
  - `secretsmanager:DescribeSecret`
  - `ssm:GetParameter`

---

### 6. Secrets & Configuration Management

#### AWS Secrets Manager
- **Secret**: `/petclinic/db_credentials`
- **내용**: 
  - CUSTOMERS_DATASOURCE_USERNAME/PASSWORD
  - VETS_DATASOURCE_USERNAME/PASSWORD
  - VISITS_DATASOURCE_USERNAME/PASSWORD

#### AWS Systems Manager Parameter Store
- **DB Host**: `/petclinic/db_host`
- **VPC ID**: `/petclinic/vpc_id`
- **Subnets**: 
  - `/petclinic/subnets/private/app`
  - `/petclinic/subnets/private/db`
  - `/petclinic/subnets/public`
- **Karpenter AMI**: `/petclinic/karpenter/ami_id`
- **AWS Account ID**: `/petclinic/aws_account_id`

#### SSM Parameters (RDS 정보)
- **Endpoint**: `/${project_name}/${environment}/rds/endpoint`
- **Username**: `/${project_name}/${environment}/rds/username` (SecureString)
- **Password**: `/${project_name}/${environment}/rds/password` (SecureString)

---

## 🗂️ Terraform 구조

### 디렉터리 구조 (리팩토링 후)

```
petclinic-test-infra/
├── modules/                    # 재사용 가능한 모듈
│   ├── vpc/                   # VPC, Subnets, NAT Gateway, VPN
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/                   # EC2 인스턴스 (Bastion, Management)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── security-groups/       # Security Groups
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/               # 환경별 구성
│   ├── dev/                  # Dev 환경
│   │   ├── main.tf          # 모듈 호출
│   │   ├── variables.tf     # 변수 정의
│   │   ├── outputs.tf       # 출력 정의
│   │   ├── terraform.tfvars # Dev 환경 변수 값
│   │   ├── backend.tf       # S3 Backend 설정
│   │   ├── versions.tf      # Provider 설정
│   │   ├── data.tf          # Data Sources
│   │   ├── locals.tf        # Local Values
│   │   ├── rds.tf           # RDS 리소스
│   │   ├── outputs_to_ssm.tf # SSM Parameters
│   │   ├── user_data_mgmt.sh # Management Server 초기화 스크립트
│   │   ├── sql/             # SQL 초기화 파일
│   │   └── mykey/            # SSH 키 저장 위치
│   └── prod/                 # Prod 환경 (추후 생성)
│
├── .backup/                   # 백업 파일
│   └── root-files/           # 리팩토링 전 파일들
│
├── README.md
├── MIGRATION_GUIDE.md        # 리팩토링 가이드
└── IMPLEMENTATION.md
```

### 모듈화 전략

#### 모듈의 특징
- **순수 모듈**: Provider 및 Backend 블록 없음
- **재사용성**: 여러 환경에서 동일한 모듈 사용
- **상대 경로**: `../../modules/...` 사용
- **입출력 명확**: variables.tf와 outputs.tf로 인터페이스 정의

#### 환경 격리
- **디렉터리 기반**: 각 환경별로 독립적인 디렉터리
- **State 분리**: 환경별로 다른 S3 경로에 State 저장
- **변수 분리**: terraform.tfvars로 환경별 값 관리

---

## 🔒 보안 기능

### 네트워크 보안
- **Private Subnet**: 애플리케이션 및 데이터베이스는 Private에 배치
- **Bastion Host**: Public Subnet에만 배치, SSH 접근 제한
- **Security Groups**: 최소 권한 원칙 적용
- **VPN 연결**: Azure와의 하이브리드 클라우드 연결

### 데이터 보안
- **암호화**: 
  - RDS: Storage 암호화 활성화
  - EBS: 모든 볼륨 암호화
  - S3: State 파일 암호화
- **비밀 관리**: 
  - AWS Secrets Manager
  - SSM Parameter Store (SecureString)
- **접근 제어**: 
  - IAM Role 기반 접근
  - Security Group 기반 네트워크 제어

### 인프라 보안
- **IMDSv2**: EC2 인스턴스 메타데이터 서비스 v2 강제
- **SSH 키**: 자동 생성, 안전한 저장
- **State 파일**: S3 Object Lock으로 보호

---

## 🚀 주요 기능

### 1. 고가용성 (High Availability)
- **Multi-AZ**: 2개 가용 영역 사용
- **Regional NAT Gateway**: 자동 확장 및 장애 조치
- **RDS Multi-AZ**: 예정 (현재 false)

### 2. 확장성 (Scalability)
- **EKS 준비**: 서브넷 태깅 및 Security Group 준비
- **Auto Scaling**: RDS 스토리지 자동 확장
- **모듈화**: 재사용 가능한 모듈 구조

### 3. 모니터링 및 관리
- **SSM Parameters**: 인프라 정보 중앙 관리
- **Secrets Manager**: 비밀 정보 중앙 관리
- **Outputs**: Terraform 출력으로 접속 정보 제공

### 4. 하이브리드 클라우드
- **Azure VPN**: AWS와 Azure 간 VPN 연결
- **Route 53 Resolver**: Azure Private DNS 연동
- **Static Routes**: Azure CIDR 라우팅

---

## 📊 기술 스택

### Infrastructure as Code
- **Terraform**: >= 1.10.0
- **HCL (HashiCorp Configuration Language)**
- **S3 Backend**: State 파일 원격 저장
- **S3 Native Lock**: DynamoDB 없이 락킹

### AWS 서비스
- **VPC**: 네트워크 격리
- **EC2**: 컴퓨팅 리소스
- **RDS**: MySQL 데이터베이스
- **IAM**: 접근 제어
- **Secrets Manager**: 비밀 관리
- **SSM Parameter Store**: 설정 관리
- **S3**: State 파일 저장

### 운영 도구
- **AWS CLI v2**: AWS 서비스 관리
- **kubectl**: Kubernetes 클러스터 관리
- **eksctl**: EKS 클러스터 생성
- **Helm**: Kubernetes 패키지 관리
- **Docker**: 컨테이너 관리

---

## 🔄 리팩토링 내용

### Before (루트 중심 구조)
```
petclinic-test-infra/
├── ec2.tf
├── vpc.tf
├── rds.tf
├── security_groups.tf
├── iam.tf
├── outputs.tf
├── variables.tf
├── terraform.tfvars
└── modules/
```

### After (디렉터리 기반 격리 구조)
```
petclinic-test-infra/
├── modules/              # 순수 모듈
├── environments/         # 환경별 구성
│   ├── dev/
│   └── prod/
└── .backup/              # 백업
```

### 리팩토링 장점
1. **환경 격리**: Dev/Prod 환경 완전 분리
2. **State 분리**: 환경별 독립적인 State 관리
3. **변수 분리**: 환경별 다른 설정 값 사용
4. **모듈 재사용**: 동일한 모듈을 여러 환경에서 사용
5. **유지보수성**: 코드 구조 명확화

---

## 📈 배포 프로세스

### 1. 초기화
```bash
cd environments/dev
terraform init -reconfigure
```

### 2. 계획 확인
```bash
terraform plan
```

### 3. 배포
```bash
terraform apply
```

### 4. 출력 확인
```bash
terraform output
```

### 5. 접속
```bash
# Bastion 접속
ssh -i mykey/petclinic-keypair.pem ubuntu@<BASTION_IP>

# Management Server 접속 (ProxyJump)
ssh -i mykey/petclinic-keypair.pem -J ubuntu@<BASTION_IP> ubuntu@<MGMT_IP>
```

---

## 🎯 주요 출력 값

### 네트워크
- VPC ID
- Subnet IDs (Public, App Private, DB Private)
- VPN Tunnel 정보

### 컴퓨팅
- Bastion Public IP
- Management Server Private IP
- SSH 접속 명령어

### 데이터베이스
- RDS Endpoint
- RDS Address
- RDS Port
- Database Name

### 보안
- Security Group IDs
- SSH Key 정보

### EKS 설정
- eksctl 클러스터 생성 명령어
- 노드 그룹 생성 명령어

---

## 📝 주요 설정 값

### Dev 환경 기본값
- **프로젝트명**: petclinic
- **환경**: dev
- **리전**: ap-northeast-2
- **VPC CIDR**: 10.0.0.0/16
- **Bastion**: t3.micro
- **Management**: t3.medium
- **RDS**: db.t3.small, 20GB

### Azure VPN 설정
- **BGP ASN**: 65000
- **Azure Public IP**: <azure-vpn-gateway-public-ip>
- **Azure CIDR**: 192.168.0.0/16
- **Azure DNS IP**: 192.168.200.4

---

## 🔧 특별 기능

### 1. S3 Native Lock
- **DynamoDB 불필요**: `use_lockfile = true` 사용
- **파일 기반 락킹**: `.tflock` 파일로 동시 접근 제어
- **Terraform 버전**: >= 1.10.0 필요

### 2. Regional NAT Gateway
- **자동 확장**: 트래픽에 따라 자동 확장
- **고가용성**: Regional 모드로 장애 조치
- **비용 최적화**: 단일 Regional NAT Gateway 사용

### 3. GTID 활성화
- **MySQL 8.0**: GTID 모드 활성화
- **복제 준비**: Master-Slave 복제 지원
- **일관성**: enforce_gtid_consistency 활성화

### 4. Management Server 자동 초기화
- **User Data**: 자동으로 모든 도구 설치
- **스크립트 생성**: EKS 클러스터 생성 스크립트 자동 생성
- **DB 연결**: RDS 연결 스크립트 자동 생성

---

## 📚 참고 자료

### 문서
- `README.md`: 프로젝트 개요 및 사용법
- `MIGRATION_GUIDE.md`: 리팩토링 가이드
- `IMPLEMENTATION.md`: 구현 상세 내용

### 모듈 문서
- `modules/vpc/README.md`: VPC 모듈 상세 설명

---

## 🎓 학습 포인트

### Terraform Best Practices
1. **모듈화**: 재사용 가능한 모듈 구조
2. **환경 격리**: 디렉터리 기반 환경 분리
3. **State 관리**: S3 Backend 사용
4. **변수 관리**: terraform.tfvars로 값 분리
5. **보안**: 민감한 정보는 SecureString 사용

### AWS Best Practices
1. **네트워크 설계**: Public/Private Subnet 분리
2. **보안 그룹**: 최소 권한 원칙
3. **IAM**: Role 기반 접근 제어
4. **암호화**: 모든 데이터 암호화
5. **고가용성**: Multi-AZ 구성

---

## ✅ 체크리스트

### 배포 전 확인사항
- [ ] Terraform 버전 >= 1.10.0
- [ ] AWS 자격 증명 설정
- [ ] S3 버킷 생성 (State 저장용)
- [ ] terraform.tfvars 값 확인
- [ ] SSH 키 경로 확인

### 보안 확인사항
- [ ] allowed_ssh_cidr 설정 (프로덕션)
- [ ] RDS 비밀번호 강도 확인
- [ ] IAM 권한 최소화 (프로덕션)
- [ ] State 파일 접근 제어

### 운영 확인사항
- [ ] RDS Multi-AZ 활성화 (프로덕션)
- [ ] 백업 보관 기간 설정
- [ ] 모니터링 설정
- [ ] 알림 설정

---

## 📞 지원 정보

### 문제 해결
1. `MIGRATION_GUIDE.md` 참고
2. Terraform 로그 확인
3. AWS 콘솔에서 리소스 상태 확인

### 롤백 방법
```bash
# 백업 디렉터리에서 파일 복원
cd /Users/hwangseung-gi/cursor_workspace/petclinic-test-infra
cp -r .backup/root-files/* .
```

---

**마지막 업데이트**: 2024-12-22
**프로젝트 버전**: 2.0 (리팩토링 완료)

