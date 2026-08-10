FROM maven:3.8.3-openjdk-17 as builder

LABEL app=bankapp

WORKDIR /src

COPY . /src

RUN mvn clean install -DskipTests=True

FROM eclipse-temurin:17-jre-alpine as deployer

COPY --from=builder /src/target/*.jar /src/target/bankapp.jar

EXPOSE 8080

ENTRYPOINT ["java","-jar","/src/target/bankapp.jar"]
