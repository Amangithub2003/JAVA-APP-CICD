FROM openjdk:17-jdk-slim

WORKDIR /app

COPY target/*.jar app.jar

# Use port 8081 to avoid conflicts
EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8081/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
