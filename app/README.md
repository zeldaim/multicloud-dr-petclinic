# 🏥 Spring PetClinic - Multi-Cloud Disaster Recovery (DR) Project

이 프로젝트는 기존 Spring PetClinic 샘플 애플리케이션을 활용하여 **AWS(Primary)와 Azure(Secondary) 간의 재해 복구(Disaster Recovery) 시스템**을 구축한 프로젝트입니다.

## 🌐 Project Architecture
본 프로젝트는 특정 클라우드 리전의 장애 상황을 가정하여, 타 클라우드 서비스로 즉시 전환 가능한 **High Availability(HA)** 구성을 목표로 합니다.

* **Primary Site:** AWS EC2 + AWS RDS (MySQL)
* **DR Site (Standby):** AWS EC2 + Azure Database for MySQL
* **Framework:** Spring Boot 3.x
* **Database:** MySQL 8.0 / 9.0

## 🛠 Multi-Cloud Configurations
Spring Profiles를 활용하여 실행 시점에 타겟 클라우드 환경을 동적으로 전환합니다.

- **AWS Profile (`aws`):** AWS RDS 엔드포인트 연결 및 메인 UI 테마 적용
- **Azure Profile (`azure`):** Azure MySQL 엔드포인트 연결 및 DR 전용 UI 배너 활성화

## ⚡ Disaster Recovery Scenario (Demo)
1. **Normal State:** 서비스가 AWS 인프라에서 정상 동작합니다.
2. **Failure Injection:** AWS RDS 또는 가용 영역에 장애가 발생한 상황을 가정합니다.
3. **Failover:** 즉시 Azure 프로필로 애플리케이션을 재가동하여 서비스 연속성을 보장합니다.
   - 실행 명령어: `java -jar -Dspring.profiles.active=azure target/*.jar`
4. **Visibility:** DR 환경 전환 시 상단 배너를 통해 현재 구동 환경이 **Azure (Disaster Recovery Site)**임을 사용자에게 알립니다.

## 🔧 Setup & Installation
```bash
# Repository Clone
git clone [https://github.com/zeldaim/aws-azure-petclinic-dr.git](https://github.com/zeldaim/aws-azure-petclinic-dr.git)
cd aws-azure-petclinic-dr

# Build
./mvnw package -DskipTests

# Run for AWS (Primary)
java -jar -Dspring.profiles.active=aws target/*.jar

# Run for Azure (DR)
java -jar -Dspring.profiles.active=azure target/*.jar
