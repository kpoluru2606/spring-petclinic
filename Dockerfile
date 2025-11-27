# Multi-stage Dockerfile for Spring PetClinic
# Stage 1: Build
FROM mcr.microsoft.com/openjdk/jdk:8-mariner AS build
WORKDIR /app

# Copy Maven wrapper and pom.xml first for better caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Make mvnw executable
RUN chmod +x mvnw

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application (skip tests for faster build)
RUN ./mvnw package -DskipTests -B

# Stage 2: Runtime
FROM mcr.microsoft.com/openjdk/jdk:8-mariner AS runtime
WORKDIR /app

# Create non-root user for security
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

# Copy the built JAR from build stage
COPY --from=build /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R petclinic:petclinic /app

# Switch to non-root user
USER petclinic

# Expose port
EXPOSE 8080

# Set JVM options for container environment
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
