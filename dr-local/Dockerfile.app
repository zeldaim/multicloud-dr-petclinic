# PetClinic 앱 이미지 (app/ 를 그대로 빌드 — 코드 수정 없음)
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY app/ .
RUN chmod +x mvnw && ./mvnw -q -B package -DskipTests -Dcheckstyle.skip -Dspring-javaformat.skip=true
FROM eclipse-temurin:17-jre
COPY --from=build /src/target/*.jar /app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
