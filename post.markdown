Get a script to download raw docker image 


[ref_so_pull]:https://stackoverflow.com/a/47624649
[ref_script_pull]:https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh


```
./download-frozen-image-v2.sh ./image/ busybox:latest
```

Unpack layer.tar containing the actual binaries

```
mkdir -p image-layer && find image -name layer.tar | xargs -n1 tar -C image-layer -xf
```


```
20-unshare.sh

```

# Overlaying different filesystems

