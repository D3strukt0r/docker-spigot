ARG SPIGOT_VERSION=latest
FROM d3strukt0r/spigot-build:${SPIGOT_VERSION}

RUN set -eux; \
    apk update; \
    apk add --no-cache \
    # Required for yq and yaml_cli (runs on Python)
    python3 py3-pip python py-pip \
    # Required to download yaml_cli
    git \
    # Required by yq
    jq; \
    # yq
    pip3 install yq; \
    # yaml_cli
    pip install git+https://github.com/Gallore/yaml_cli; \
    # Cleanup
    apk del git

COPY bin /usr/local/bin

WORKDIR /data
ENTRYPOINT ["docker-entrypoint.sh"]
