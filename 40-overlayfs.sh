#!/bin/bash

set -eux  

sudo mkdir -p /upper /lower /work /merged
sudo chmod 777 /upper /lower /work /merged
echo 'upper foo' > /upper/foo
echo 'upper bar' > /upper/bar
echo 'lower bar' > /lower/bar
echo 'lower quux' > /lower/quux
sudo mount -t overlay overlay -olowerdir=/lower,upperdir=/upper,workdir=/work /merged 
