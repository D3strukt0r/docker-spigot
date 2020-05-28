ARG SPIGOT_VERSION=latest
FROM d3strukt0r/spigot-build:${SPIGOT_VERSION}

COPY bin /usr/local/bin
COPY build /build

WORKDIR /build
RUN set -eux; \
    apk update; \
    apk add --no-cache bash; \
    /build/build.sh

EXPOSE 25565
VOLUME ["/data"]
WORKDIR /data
ENTRYPOINT ["docker-entrypoint"]
