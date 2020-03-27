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

COPY --from=build /app/spigot.jar /app/
COPY src/*.sh /usr/local/bin/

RUN \
apk add \
\
# Terminal
bash \
# Java environment for Spigot
openjdk8-jre \
# Required for yq and yaml_cli (runs on Python)
python3 py3-pip python py-pip \
# Required to download yaml_cli
git \
# Required by yq
jq && \
# yq
pip3 install yq && \
# yaml_cli
pip install git+https://github.com/Gallore/yaml_cli && \
# Remove .sh for easier usage (https://stackoverflow.com/questions/7450818/rename-all-files-in-directory-from-filename-h-to-filename-half)
for file in /usr/local/bin/*.sh; do mv "$file" "${file/.sh/}"; done && \
# Add execution permissions (not by default)
chmod 755 /usr/local/bin/*

VOLUME ["/data"]

WORKDIR /data
ENTRYPOINT ["entrypoint"]
