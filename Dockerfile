# -------
# Builder
# -------

FROM alpine:latest AS build

RUN apk add curl git openjdk8-jre
RUN git config --global --unset core.autocrlf; exit 0

ARG SPIGOT_VERSION=latest

# Download the builder
WORKDIR /app/build
RUN curl -o BuildTools.jar -fL https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

# Execute the builder
WORKDIR /app/build/data
RUN java -Xmx1G -jar ../BuildTools.jar --rev ${SPIGOT_VERSION}

# Copy the resulting file into a known file name
RUN find -iname 'spigot-*.jar' -exec mv {} /app/spigot.jar \;

# -------
# Final Container
# -------

FROM openjdk:8-jre-slim

COPY --from=build /app/spigot.jar /app/spigot.jar

VOLUME ["/data"]

ENV JAVA_BASE_MEMORY=512M
ENV JAVA_MAX_MEMORY=512M

EXPOSE 25565

WORKDIR /data
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
