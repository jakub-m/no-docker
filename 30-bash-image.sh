#!/bin/bash

set -eux
set -o pipefail

./download-frozen-image-v2.sh ./image-bash/ bash:latest
mkdir -p image-bash-layer
find image-bash -name layer.tar | xargs -n1 tar -C image-bash-layer -xf
