#!/bin/bash

set -eux  

sudo mkdir -p /upper /lower /work /merged
sudo chmod 777 /upper /lower /work /merged
sudo mount -t overlay overlay -olowerdir=/lower,upperdir=/upper,workdir=/work /merged 
