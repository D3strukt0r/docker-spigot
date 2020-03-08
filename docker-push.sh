#!/bin/bash

REPO="$DOCKER_USERNAME"/spigot

if [ "$TRAVIS_BRANCH" == "master" ]; then
    if [ "$SPIGOT_VERSION" == "latest" ]; then
        # Upload to "latest"
        docker tag spigot "$REPO":latest
        docker push "$REPO":latest
    else
        # Or to any given build number
        docker tag spigot "$REPO":"$SPIGOT_VERSION"
        docker push "$REPO":"$SPIGOT_VERSION"
    fi
elif [ "$TRAVIS_BRANCH" == "develop" ]; then
    if [ "$SPIGOT_VERSION" == "latest" ]; then
        # In the "develop" branch only upload to "nightly"
        docker tag spigot "$REPO":nightly
        docker push "$REPO":nightly
    fi
else
    echo "Skipping deployment because it's neither master nor develop"
    exit 0;
fi
