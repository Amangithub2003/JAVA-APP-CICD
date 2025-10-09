FROM openjdk:17-jdk-slim

WORKDIR /app

COPY target/*.jar app.jar

# Avoid conflicts: use port 8081
EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8081/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
