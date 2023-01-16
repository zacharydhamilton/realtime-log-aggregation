FROM maven:3.8.3-openjdk-17 AS builder
COPY src /usr/src/app/src
COPY pom.xml /usr/src/app
RUN mvn -f /usr/src/app/pom.xml clean package

FROM openjdk:17.0.1-jdk-slim
COPY --from=builder /usr/src/app/target/logger-1.0.0.jar /usr/app/logger-1.0.0.jar

ENTRYPOINT ["java", "-jar", "/usr/app/logger-1.0.0.jar"]