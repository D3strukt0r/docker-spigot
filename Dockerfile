# -------
# Builder
# -------

FROM alpine:latest AS build

RUN apk add curl git openjdk8-jre

ARG SPIGOT_VERSION=latest

WORKDIR /app/build
RUN curl -o BuildTools.jar -fL https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

WORKDIR /app
RUN git config --global --unset core.autocrlf; exit 0
RUN java -Xmx1G -jar build/BuildTools.jar --rev ${SPIGOT_VERSION}

WORKDIR /app/export
WORKDIR /app
RUN find -iname 'spigot-*.jar' -exec mv {} export/spigot.jar \;

# -------
# Final Container
# -------

FROM openjdk:8-jre-slim

COPY --from=build /app/export/spigot.jar /app/spigot.jar

ENV JAVA_BASE_MEMORY=512M
ENV JAVA_MAX_MEMORY=512M

VOLUME ["/data"]
EXPOSE 25565

WORKDIR /data
ENTRYPOINT ["java", "-Xms${JAVA_BASE_MEMORY}", "-Xmx${JAVA_MAX_MEMORY}", "-jar", "../app/spigot.jar"]
