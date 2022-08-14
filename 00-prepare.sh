#!/bin/bash

set -eux

sudo apt-get install -y git golang jq curl

curl -O https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh

chmod a+x download-frozen-image-v2.sh
