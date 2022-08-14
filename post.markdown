Get a script to download raw docker image 


[ref_so_pull]:https://stackoverflow.com/a/47624649
[ref_script_pull]:https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh


```
./download-frozen-image-v2.sh busybox-latest-image  busybox:latest
```

Unpack layer.tar containing the actual binaries
```
mkdir layer
find . -name layer.tar | xargs -n1 tar -C layer -xf
```

```
# Go to the directory that will become a new root.
cd layer
# Create directory that will be used to mount /proc/
mkdir proc
# Run the shell from the new namespace!
sudo unshare --mount-proc --fork --pid --root=$PWD  bin/sh
```

# Overlaying different filesystems

