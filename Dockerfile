FROM maven:3.9-eclipse-temurin-17 AS builder

LABEL app=bankapp

WORKDIR /src

COPY pom.xml .
RUN mvn dependency:resolve

COPY . .

RUN mvn clean install -DskipTests=true

FROM eclipse-temurin:17-jre-alpine AS deployer

# Install curl for healthchecks (lightweight alternative to wget on Alpine)
# hadolint ignore=DL3018
RUN apk add --no-cache dumb-init curl && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    # Remove setuid/setgid bits for security hardening
    find / -xdev -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /src/target/*.jar bankapp.jar

# Set secure permissions
RUN chmod 500 /app && \
    chmod 400 bankapp.jar

EXPOSE 8080

USER appuser

# Use curl instead of wget (built-in to Alpine via libc, lighter)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["curl", "-f", "http://localhost:8080/actuator/health"]

# Run with read-only root filesystem support
ENTRYPOINT ["dumb-init", "java", "-XX:+UseStringDeduplication", "-XX:MaxRAMPercentage=75", "-jar", "bankapp.jar"]
