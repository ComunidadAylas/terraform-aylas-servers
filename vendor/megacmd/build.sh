#!/bin/sh -e

docker build -t megacmd_build .
docker run --rm megacmd_build > megacmd_arm64.deb
docker image rm megacmd_build || true
