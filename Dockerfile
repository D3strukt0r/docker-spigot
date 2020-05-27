FROM alpine:latest

COPY bin /usr/local/bin
COPY build /build

ARG SPIGOT_VERSION=latest

WORKDIR /build
RUN set -eux; \
    apk update; \
    apk add bash nano; \
    /build/build.sh

VOLUME ["/data"]

WORKDIR /data
ENTRYPOINT ["docker-entrypoint"]
