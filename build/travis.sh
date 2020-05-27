#!/bin/bash

if [[ -v DOCKER_PASSWORD && -v DOCKER_USERNAME ]]; then
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
fi

REPO=spigot
docker build --build-arg "$SPIGOT_VERSION" -t $REPO .

if [[ -v DOCKER_PASSWORD && -v DOCKER_USERNAME ]]; then
    if [ "$TRAVIS_BRANCH" == "master" ]; then
        if [ "$SPIGOT_VERSION" == "latest" ]; then
            # Upload to "latest"
            DOCKER_PUSH_TAG=latest
        else
            # Or to any given build number
            DOCKER_PUSH_TAG="$SPIGOT_VERSION"
        fi
    elif [ "$TRAVIS_BRANCH" == "develop" ]; then
        if [ "$SPIGOT_VERSION" == "latest" ]; then
            # In the "develop" branch only upload to "nightly"
            DOCKER_PUSH_TAG=nightly
        fi
    else
        echo "Skipping deployment because it's neither master nor develop"
        exit
    fi

    # Upload to Docker Hub
    docker tag "$REPO" "$DOCKER_USERNAME/$REPO:$DOCKER_PUSH_TAG"
    docker push "$DOCKER_USERNAME/$REPO:$DOCKER_PUSH_TAG"
fi
