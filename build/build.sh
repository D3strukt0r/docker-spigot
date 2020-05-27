#!/bin/bash

set -eux

# openjdk8-jre (Java environment for Spigot)
# python3 py3-pip python py-pip (Required for yq and yaml_cli (runs on Python))
# git (Required to download yaml_cli)
# jq (Required by yq)
apk add --no-cache \
    curl \
    openjdk8-jre \
    python3 \
    py3-pip \
    python \
    py-pip \
    git \
    jq
pip3 install yq
pip install git+https://github.com/Gallore/yaml_cli

# Remove .sh for easier usage
# https://stackoverflow.com/questions/7450818/rename-all-files-in-directory-from-filename-h-to-filename-half
for file in /usr/local/bin/*.sh; do
    mv "$file" "${file/.sh/}"
done

# Build spigot.jar
if [[ ! -f BuildTools.jar ]]; then
    curl -o BuildTools.jar -fsSL https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
fi

if [[ ! -d /app ]]; then
    mkdir /app
fi
if [[ ! -d data ]]; then
    mkdir data
fi
cd data
java -Xms4G -Xmx4G -jar ../BuildTools.jar --rev "${SPIGOT_VERSION}" -o /app

# Rename
find /app -iname 'spigot-*.jar' -exec mv {} /app/spigot.jar \;

# Cleanup
rm -r /build /root/.m2 /root/cache
