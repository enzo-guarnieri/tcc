# -------------------------
# STAGE 1 — Build com Gradle
# -------------------------
FROM gradle:9.3.1-jdk17 AS builder

WORKDIR /app

# Copia tudo para o container
COPY . .

# Gera o shadowJar
RUN ./gradlew :connector:clean :connector:shadowJar --no-daemon

# -------------------------
# STAGE 2 — Runtime leve
# -------------------------
FROM eclipse-temurin:17-jre

WORKDIR /app

# Copia o jar já gerado
COPY --from=builder /app/connector/build/libs/basic-connector.jar app.jar


# Copia a pasta de configurações
COPY configuracoes /app/configuracoes

ENTRYPOINT ["java"]