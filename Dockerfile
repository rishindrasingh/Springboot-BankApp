FROM dhi.io/eclipse-temurin:17-jdk-alpine-dev AS builder

LABEL app=bankapp

# Install Maven in the build stage with explicit verification
# hadolint ignore=DL3018
RUN apk add --no-cache maven && \
    mvn --version

WORKDIR /src

# Copy pom.xml first for better layer caching
COPY pom.xml .

# Resolve dependencies
RUN mvn dependency:resolve

# Copy application source code
COPY . .

# Build application
RUN mvn clean install -DskipTests=true

FROM dhi.io/eclipse-temurin:17-jre-alpine-dev AS deployer

# Install security updates and necessary packages
# hadolint ignore=DL3018
RUN apk update && \
    apk upgrade && \
    apk add --no-cache dumb-init curl && \
    rm -rf /var/cache/apk/* && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    find / -xdev -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null; true

WORKDIR /app

# Copy JAR from builder stage with proper ownership
COPY --from=builder --chown=appuser:appgroup /src/target/*.jar bankapp.jar

# Set secure permissions on directories and files
RUN chmod 500 /app && \
    chmod 400 bankapp.jar

EXPOSE 8080

USER appuser

# Health check with curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["curl", "-sf", "http://localhost:8080/actuator/health"]

# Run with dumb-init for proper signal handling and optimized JVM settings
ENTRYPOINT ["dumb-init", "java", "-XX:+UseStringDeduplication", "-XX:MaxRAMPercentage=75", "-jar", "bankapp.jar"]
