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

FROM alpine:latest

RUN apk add git openjdk8-jre python3 py-pip jq bash
RUN pip install shyaml
RUN pip install git+https://github.com/Gallore/yaml_cli

COPY --from=build /app/spigot.jar /app/

COPY src/minecraft-console.sh /usr/local/bin/console
RUN chmod 755 /usr/local/bin/console

COPY src/docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]

WORKDIR /data
ENTRYPOINT ["docker-entrypoint.sh"]
