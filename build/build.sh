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

# Cleanup
rm -r /build
