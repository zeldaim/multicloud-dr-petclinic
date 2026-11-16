# Multi-Cloud DR — Spring PetClinic (AWS Primary → Azure DR)

AWS를 주 사이트, Azure를 재해 복구(DR) 사이트로 두고 Spring PetClinic 서비스를 이어 가는 멀티클라우드 DR 프로젝트입니다.
인프라는 Terraform(IaC)으로 만들고, 두 클라우드를 Site-to-Site VPN 으로 잇고, DB는 AWS DMS로 RDS MySQL에서 Azure MySQL로 복제하며, 장애가 나면 애플리케이션을 Azure 쪽으로 전환합니다.

이 문서는 세 부분으로 나뉩니다.

1. **[원래 프로젝트](#1-원래-프로젝트-2025-12-팀)** (2025-12, 팀) — 구조와 내 담당(인프라 구현 전반)
2. **[개인 검증](#2-개인-검증-2026-11)** (2026-11) — 클라우드 없이 다시 확인한 것: [전환 절차](dr-local/README.md) · [Terraform](tf-local/README.md)
3. **[한계](#3-한계)** — 검증하지 못한 것

[![DR 시연](dr-local/media/page_before_after.png)](dr-local/media/dr_demo_2x.mp4)

## 출처와 역할

- **애플리케이션**: [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) 공식 샘플(Apache-2.0, `app/LICENSE.txt`)을 기반으로 했습니다. 앱 코드는 Spring 팀의 것이며, 이 레포에서 바꾼 부분은 DR 프로필(`application-aws.properties`, `application-azure.properties`)과 전환 시 화면 상단 DR 배너입니다.
- **인프라·DR 구성**: 팀 프로젝트(2025-12)로 진행했고, 저는 **인프라 구현 전반**을 담당했습니다. AWS·Azure Terraform 코드, DMS 복제 구성, 장애 전환 절차를 완성했습니다. 이 레포는 그 작업을 개인 포트폴리오용으로 다시 정리한 것입니다.

---

## 1. 원래 프로젝트 (2025-12, 팀)

### 아키텍처

```
                 Route 53 (장애 조치)
                        │
                 CloudFront (오리진 그룹)
                ┌───────┴────────────────────┐
             1순위                          2순위
                │                            │
 ┌──────────── AWS (Primary) ────────────┐   Azure 정적 장애 안내 페이지 (CDN · SSL)
 │ ALB (HTTPS) → EC2 PetClinic (aws)     │
 │        │                              │        ┌──────────── Azure (DR) ─────────────┐
 │   RDS MySQL ── AWS DMS (full load+CDC)┼─ S2S ─▶│   MySQL Flexible Server (GTID ON)    │
 │                                       │  VPN   │   PetClinic (azure 프로필, DR 배너)  │
 │ Route 53 Resolver ────────────────────┼───────▶│   Private DNS Resolver               │
 └───────────────────────────────────────┘        └──────────────────────────────────────┘
 장애 시: 앱을 azure 프로필로 기동 → 복제해 둔 Azure DB 로 서비스 계속 (화면에 "Disaster Recovery Site" 배너)
```

### 내 담당 — 인프라 구현 전반

AWS · Azure 인프라 구현 전반을 맡았다. 영역별 주요 구현은 아래와 같다.

| 영역 | 내용 | 이 레포의 근거 |
|---|---|---|
| AWS · Azure 인프라 (Terraform) | VPC(2 AZ) · 서브넷 · NAT · Bastion · EC2 · RDS / VNet · 위임 서브넷 · MySQL Flexible Server · Private DNS | [`infra/aws/`](infra/aws/), [`infra/azure/`](infra/azure/) |
| Site-to-Site VPN (정적 IP) | AWS VPN Gateway · Customer Gateway · 정적 라우트 ↔ Azure VPN Gateway · Local Network Gateway (IPsec) | [`infra/aws/modules/vpc/main.tf`](infra/aws/modules/vpc/main.tf), [`infra/azure/network.tf`](infra/azure/network.tf) |
| DB 복제 (AWS DMS) | RDS 덤프 → Azure 적재, DMS full load + CDC 연동, 트러블슈팅 | RDS 쪽 전제(binlog ROW · GTID · 백업)와 Azure 쪽 GTID 설정이 코드에 있음. DMS 작업 자체는 콘솔에서 구성(코드 없음) |
| 이름 해석 | AWS 에서 Azure MySQL 사설 FQDN 을 찾도록 Route 53 Resolver ↔ Azure Private DNS Resolver 연동 | [`infra/aws/modules/vpc/main.tf`](infra/aws/modules/vpc/main.tf), [`infra/azure/network.tf`](infra/azure/network.tf) |
| ALB HTTPS · 장애 안내 페이지 | ALB HTTPS, 장애 조치용 정적 페이지 + CDN(SSL) | 콘솔 구성(코드 없음) |
| 앱 DR 프로필 · 배너 | `aws` / `azure` 프로필, 전환 시 DR 배너 | [`app/`](app/) |

### 구조

```
infra/
  aws/      Terraform — VPC(2 AZ, NAT HA), Site-to-Site VPN, Route 53 Resolver, Bastion, EC2, RDS MySQL, SG, SSM/Secrets
  azure/    Terraform — VNet, VPN Gateway, Private DNS Resolver, Bastion,
            Azure Database for MySQL Flexible Server (Private DNS, GTID on → DMS 복제 대상)
app/        Spring PetClinic + DR 프로필 (aws / azure) · 전환 시 화면 상단 DR 배너
docs/       구현 근거, 마이그레이션 가이드, 발표 자료, AWS 인프라 상세
dr-local/   개인 검증 — 전환 절차 (Docker)
tf-local/   개인 검증 — Terraform (validate · Trivy · terraform test)
```

### 실행

DB 접속 정보는 코드에 넣지 않고 환경변수로 받는다.

```bash
cd app && ./mvnw package -DskipTests

# Primary (AWS)
DB_HOST=<rds-endpoint> DB_USERNAME=<user> DB_PASSWORD=<pw> \
  java -jar -Dspring.profiles.active=aws target/*.jar

# Failover (Azure)
DB_HOST=<azure-mysql-host> DB_USERNAME=<user> DB_PASSWORD=<pw> \
  java -jar -Dspring.profiles.active=azure target/*.jar
```

인프라:

```bash
cd infra/aws/environments/dev && terraform init && terraform apply
cd infra/azure && terraform init && terraform apply
# 시연 후 비용 정리
terraform destroy
```

---

## 2. 개인 검증 (2026-11)

클라우드 계정·비용 없이, 원래 프로젝트의 **전환 절차**와 **인프라 코드**를 다시 확인했다. 기존 코드는 고치지 않았다.

### 2-1. 전환 절차 로컬 검증 — 자동 전환과 RTO · RPO 측정 → [`dr-local/`](dr-local/README.md)

같은 구조를 Docker 로 다시 만들고(MySQL 주/DR 복제가 DMS 역할, nginx 가 진입점), 수동 전환을 `failover.sh` 로 자동화해 실제로 측정했다. 앱 코드는 고치지 않았다.

| RTO | RPO | 전환 중 실패한 쓰기 |
|---|---|---|
| **18.7초** (재실행 20.8 · 25.2 · 30.6초) | **0건** / 성공 응답 105건 | 27건 / 132건 |

찾은 것: `aws` 프로필만으로는 빈 DB 에서 앱이 뜨지 않음(H2 스키마 실행 → `mysql,aws` 프로필 필요), 복제만으로는 DMS 를 대신할 수 없음(full load → CDC 순서 필요), 진입점 프록시의 Host 헤더 누락. 시연 영상은 실제 화면 녹화다.

### 2-2. Terraform 로컬 검증 → [`tf-local/`](tf-local/README.md)

| 단계 | 결과 |
|---|---|
| `terraform validate` | AWS · Azure 통과 (AWS fmt 불일치 3파일, Azure `enable_bgp` deprecated 경고) |
| Trivy 설정 점검 | HIGH · CRITICAL 11건 |
| `terraform test` + mock provider | AWS 4/4 · Azure 4/4 통과 — DMS CDC 전제, DB 비공개 · 암호화, IPsec VPN, 두 클라우드 대역 비겹침 |
| 음성 시험 | 값을 틀리게 바꾸면 해당 시험이 실패함을 확인 (AWS · Azure 각 1건) |

찾은 것:
- **SSH 가 인터넷 전체에 열림** — AWS bastion SG 기본값 `0.0.0.0/0`, Azure VM NSG `*`
- **Azure MySQL `require_secure_transport=OFF`** — 앱 azure 프로필은 `useSSL=true`, 서로 맞지 않음
- **Azure DB 이름 `petclinic-dr-db`** — 앱은 `petclinic` 을 기대 (DMS 가 스키마를 만들면 무관, 확인 필요)

---

## 3. 한계

- **로컬 전환 검증은 클라우드가 아니다.** DMS 는 MySQL 복제로, Route 53 · CloudFront 는 nginx 로 대신했다. DNS TTL, 클라우드 간 지연, DMS 의 실제 동작은 재현되지 않으므로 RTO 18.7초는 클라우드 값이 아니다.
- **Terraform 시험은 설정 값만 본다.** mock provider 라 실제 API 오류 · 할당량, VPN 터널 연결, 복제 성공 여부는 증명하지 못한다.
- **DMS · ALB · CloudFront · Route 53 장애 조치는 콘솔에서 구성해 코드가 없다.** 이 부분은 재현 · 시험 대상에서 빠져 있다.

## 로드맵

- [ ] AWS·Azure Terraform 최신 provider로 다시 apply, 변수·tfvars 정리
- [ ] DMS 복제 작업(full load + CDC)을 Terraform으로 코드화
- [ ] Trivy 지적 사항 수정 (SSH 대역 제한, egress 제한) 후 기록 시험을 정책 시험으로 전환
- [x] 수동 전환 → 헬스체크 기반 자동 전환 — **로컬 검증 완료** (`dr-local/failover.sh`). 클라우드 적용(Route 53 / Traffic Manager)은 남음
- [x] RTO/RPO 측정 — **로컬: RTO 18.7초 · RPO 0건** (`dr-local/results_2026-11-16/`). 클라우드 값은 남음
- [x] Terraform 로컬 검증 — validate · Trivy · `terraform test` (`tf-local/`)
- [x] 시연 영상·스크린샷 (로컬) — 클라우드 비용 기록은 남음
