FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /app

COPY . .

RUN chmod +x ./mvnw

RUN ./mvnw clean package -DskipTests


FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

COPY --from=build /app/target/*.jar /app/app.jar

RUN chmod +x /app/app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
