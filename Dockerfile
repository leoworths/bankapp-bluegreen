
FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /app

# Copy the necessary files for Maven wrapper to work
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./

# Preload dependencies and verify wrapper config
RUN chmod +x mvnw && ./mvnw dependency:go-offline

# Now copy the rest of the source code
COPY src/ src/

# Build the project
RUN ./mvnw clean package -DskipTests

# Step 2: Create the runtime image
FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Copy the built jar from the build image
COPY --from=build /app/target/*.jar /app/app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
