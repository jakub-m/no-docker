#!/bin/bash
set -eu
set -x

while true; do
    fswatch -1 -r .
    rsync -avzt -e 'ssh -p 10022' ./virtualbox-shared dev@localhost:/home/dev/
    sleep 1
done
