FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY services/api/pom.xml ./pom.xml
RUN mvn -B dependency:go-offline
COPY services/api/src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app app
COPY --from=build /app/target/api-0.0.1-SNAPSHOT.jar ./app.jar
USER app

EXPOSE 10000
ENV SERVER_PORT=10000
ENTRYPOINT ["java", "-jar", "app.jar"]
