#!/bin/bash

set -eux

cd image-layer
mkdir -p proc

sudo unshare --mount-proc --fork --pid --root=$PWD  bin/sh
