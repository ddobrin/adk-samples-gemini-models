# Multi-stage build to compile ADK Java from source
FROM maven:3.9-eclipse-temurin-25-alpine AS adk-build

# Install git to clone the repository
RUN apk add --no-cache git

# Set working directory
WORKDIR /adk

# Clone the ADK Java repository
RUN git clone https://github.com/google/adk-java.git .

# First, install the parent POM
RUN mvn install -N -DskipTests

# Build all ADK modules
RUN mvn clean install -DskipTests

# Application build stage
FROM maven:3.9-eclipse-temurin-25-alpine AS build

# Copy ADK artifacts from previous stage
COPY --from=adk-build /root/.m2/repository /root/.m2/repository

# Set working directory
WORKDIR /app

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Copy the built jar from build stage
COPY --from=build /app/target/*.jar app.jar

# Copy the compiled classes so ADK can discover agents
COPY --from=build /app/target/classes ./target/classes

# Copy source files for reference (optional but helpful for debugging)
COPY --from=build /app/src ./src

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
