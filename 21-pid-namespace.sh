#!/bin/bash

set -eu


cd image-busybox-layer


echo "run 'sleep 1111' in the parent process"

sleep 1111 &
ps aux | grep sleep

echo "run 'sleep 2222' in a child forked process in pid namespace"
sudo unshare --mount-proc  --fork --pid --root=$PWD bin/sh -c 'sleep 2222 & ; '



