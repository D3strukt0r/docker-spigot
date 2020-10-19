FROM openjdk:8-alpine

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG SPIGOT_BASE_URL=https://github.com/D3strukt0r/spigot-build/releases/download/
ARG SPIGOT_VERSION=""
ARG SPIGOT_FILE_URL=/spigot.jar
# Use "https://github.com/D3strukt0r/spigot-build/releases/latest/download/spigot.jar" for latest
ARG SPIGOT_URL=${SPIGOT_BASE_URL}${SPIGOT_VERSION}${SPIGOT_FILE_URL}

WORKDIR /app

# hadolint ignore=DL3018, DL3013
RUN set -eux; \
    apk update; \
    apk add --no-cache \
        bash \
        bash-completion \
        curl \
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
    \
    # Cleanup
    apk del git; \
    \
    # Custom bash config
    { \
        echo 'source /etc/profile.d/bash_completion.sh'; \
        # <green> user@host <normal> : <blue> dir <normal> $#
        echo 'export PS1="🐳 \e[38;5;10m\u@\h\e[0m:\e[38;5;12m\w\e[0m\\$ "'; \
    } >"$HOME/.bashrc"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3020
ADD ${SPIGOT_URL} /opt/spigot.jar
COPY docker/console.sh /usr/local/bin/console
COPY docker/interactive-console.sh /usr/local/bin/interactive-console
COPY docker/spigot-start.sh /usr/local/bin/spigot-start

EXPOSE 25565

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]
CMD ["spigot"]
