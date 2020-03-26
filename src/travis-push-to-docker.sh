#!/bin/bash

REPO="$DOCKER_USERNAME"/spigot

if [ "$TRAVIS_BRANCH" == "master" ]; then
    if [ "$SPIGOT_VERSION" == "latest" ]; then
        # Upload to "latest"
        TARGET="$REPO":latest
    else
        # Or to any given build number
        TARGET="$REPO":"$SPIGOT_VERSION"
    fi
elif [ "$TRAVIS_BRANCH" == "develop" ]; then
    if [ "$SPIGOT_VERSION" == "latest" ]; then
        # In the "develop" branch only upload to "nightly"
        TARGET="$REPO":nightly
    fi
else
    echo "Skipping deployment because it's neither master nor develop"
    exit 0
fi

# Upload to Docker Hub
docker tag spigot "$TARGET"
docker push "$TARGET"
