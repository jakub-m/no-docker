#!/bin/bash

set -eux
set -o pipefail

./download-frozen-image-v2.sh ./image-busybox/ busybox:latest
mkdir -p image-busybox-layer
find image-busybox -name layer.tar | xargs -n1 tar -C image-busybox-layer -xf
