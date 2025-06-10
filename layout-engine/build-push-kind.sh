#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <image-tag>"
    exit 1
fi

podman build -t="aj.net.nz/showroom/showroom-layout:$1" .
podman save aj.net.nz/showroom/showroom-layout:$1 -o showroom-layout-$1.image
kind load image-archive showroom-layout-$1.image
rm -fr showroom-layout-$1.image

echo "Build and pushed to kind image: aj.net.nz/showroom/showroom-layout:$1"