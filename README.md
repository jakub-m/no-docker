---
layout: post
title:  "Running Docker images without Docker"
date:   2022-09-10 00:00:00 -0000

---

I wrote this post trying to learn how [Docker][ref_docker] works under the hood. My learning goal was to run a Docker image without Docker.

[ref_docker]:https://en.wikipedia.org/wiki/Docker_(software)

tl;dr: Surprisingly, Docker is not magic. Docker uses Linux cgroups, namespaces, overlayfs and other Linux mechanisms. Below I try to use those mechanisms by hand.

To reproduce the learning steps, clone [no-docker git repo][ref_no_docker] and follow the post and run the scripts.  I used Debian run from VirtualBox. Start with running [00-prepare.sh][ref_00_prepare_sh] to install all the dependencies and build a small [`tool` in Go][ref_tool_go] that we will use for experimenting.

[00-prepare.sh][ref_00_prepare_sh]
```
#!/bin/bash
set -eux
sudo apt-get install -y git golang jq curl psmisc
curl -O https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh
chmod a+x download-frozen-image-v2.sh
go build -o tool tool.go
```

[ref_no_docker]:https://github.com/jakub-m/no-docker
[ref_so_pull]:https://stackoverflow.com/a/47624649
[ref_script_pull]:https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh

# Docker image

Let's download and un-archive [busybox image][ref_busybox] by running [10-busybox-image.sh][ref_10_busybox_image].  You can see that a Docker image is just a nested tar archive:


[10-busybox-image.sh][ref_10_busybox_image]
```
#!/bin/bash

set -eux
set -o pipefail

./download-frozen-image-v2.sh ./image-busybox/ busybox:latest
mkdir -p image-busybox-layer
find image-busybox -name layer.tar | xargs -n1 tar -C image-busybox-layer -xf
```

[ref_busybox]:https://hub.docker.com/_/busybox


```
$ tree image-busybox
image-busybox
|-- a01835d83d8f65e3722493f08f053490451c39bf69ab477b50777b059579198f.json
|-- b906f5815465b0f9bf3760245ce063df516c5e8c99cdd9fdc4ee981a06842872
|   |-- json
|   |-- layer.tar
|   `-- VERSION
|-- manifest.json
`-- repositories
```

`layer.tar` is a file tree with busybox tooling:

```
image-busybox-layer/
|-- bin
(...)
|   |-- less
|   |-- link
|   |-- linux32
|   |-- linux64
|   |-- linuxrc
|   |-- ln
(...)
|-- etc
|   |-- group
(...)
```


# namespace magic

[Linux namespaces][ref_linux_namespaces] create a separate "view" on Linux resources, such that one process can see the resources differently than other resources. The resources can be PIDs, file system mount points, network stack, and others.  You can see all the current namespaces with `lsns`. Let's see how isolating and nesting PIDs look in practice with PID [namespace][ref_pid_namespace].

[ref_namespaces]:https://en.wikipedia.org/wiki/Linux_namespaces
[ref_linux_namespaces]:https://man7.org/linux/man-pages/man7/namespaces.7.html
[ref_pid_namespace]:https://en.wikipedia.org/wiki/Linux_namespaces#Process_ID_(pid)

[unshare][ref_unshare] system call and a command allows to set the separate namespace for a process. Run [20-unshare.sh][ref_20_unshare] to fork a shell from busybox with a separate PID namespace, with a separate file system root. 

[20-unshare.sh][ref_20_unshare]
```
#!/bin/bash

set -eux

cd image-busybox-layer
mkdir -p proc

sudo unshare --mount-proc \
    --fork \
    --pid \
    --cgroup \
    --root=$PWD \
    bin/sh
```

Have a look around. You will see that the root directory of the forked process is restricted ("jailed") to the directory we specified when forking the shell. Now run the `tool` and see how the same process looks from the "inside" and "outside" of the forked shell. First copy the tool to `image-busybox-layer/`, then run the tool from the forked shell:

```
# Run from the forked shell.  It does nothing but sleep.

./tool -hang hello &
```

Restricting a directory tree of a process to a subdirectory is done with [chroot][ref_chroot]. You can check the actual root directory by checking /proc/\*/root of processes:

```
# Run this from the parent (outside) shell

dev@debian:~/no-docker$ find  /proc/$(pidof tool) -name root -type l 2>/dev/null | sudo xargs -n1 ls -l
lrwxrwxrwx 1 root root 0 Aug 27 22:03 /proc/1985/task/1985/root -> /home/dev/no-docker/image-busybox-layer
(...)
```

[ref_chroot]:https://man7.org/linux/man-pages/man1/chroot.1.html
[ref_unshare]:https://man7.org/linux/man-pages/man1/unshare.1.html

You can also see how the PID namespaces work. The `tool` in the parent shell and in the forked shell have separate PID numbers. Also, the parent shell sees the processes run in the forked shell, but not vice-versa.

```
# from the forked shell
/ # ps aux | grep '[t]ool'
    7 root      0:00 ./tool -hang hello
```

```
# from the parent shell
dev@debian:~$ ps aux | grep '[t]ool'
root       464  0.0  0.2 795136  2724 pts/1    Sl   10:16   0:00 ./tool -hang hello
```

# cgroups, limiting resources

While namespaces isolate resources, [cgroups (control groups)][ref_cgroup] put limits on those resources. You can find the control group of our hanging tool with the following, run from the parent shell:

```
dev@debian:~$ cat /proc/$(pidof tool)/cgroup
0::/user.slice/user-1000.slice/session-92.scope
```

[ref_cgroup]:https://docs.kernel.org/admin-guide/cgroup-v2.html

Let's now use cgroups to see how we can cap memory of the forked shell.

First, run the tool with -mb option to make it allocate n MBs of memory:


```
# kill the previous tool if it still runs
killall -9 tool
./tool -mb 200
```

Find the file controlling the maximum memory of the tool process:

```
find /sys/fs/cgroup/ | grep $( cat /proc/$(pidof tool)/cgroup | cut -d/ -f 2-) | grep memory.max
/sys/fs/cgroup/user.slice/user-1000.slice/session-92.scope/memory.max
```

"/sys/fs/cgroup" is a mount point for cgroups file system:

```
mount | grep cgroup
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot)
```

["memory.max"][ref_memory_controller] is a memory hard limit in the memory controller. Passing the hard limit causes OOM when memory usage cannot be reduced (more about it in a while).

[ref_memory_controller]:https://facebookmicrosites.github.io/cgroup2/docs/memory-controller.html

Let's put 100MB limit:

```
sudo sh -c 'echo 100m > /sys/fs/cgroup/user.slice/user-1000.slice/session-92.scope/memory.max'
```

You will notice that the tool process... was not killed. How come? if you inspect [memory.events][ref_memory_controller] file, you will see that "max" entry increments.

```
cat /sys/fs/cgroup/user.slice/user-1000.slice/session-92.scope/memory.events

low 0
high 0
max 3534 << this changes when you run over the max limit
oom 0
oom_kill 0
```

The process was not killed because OS swapped the excessive memory. Check `cat /proc/swaps`, print it several times to see how it changes:

```
dev@debian:~/no-docker$ while [ 1 ]; do cat /proc/swaps; sleep 2; done
Filename				Type		Size		Used		Priority
/dev/sda5                               partition	998396		2372		-2
Filename				Type		Size		Used		Priority
/dev/sda5                               partition	998396		2372		-2

# here I run the tool, you can see how the memory is swapped

Filename				Type		Size		Used		Priority
/dev/sda5                               partition	998396		103860		-2
Filename				Type		Size		Used		Priority
/dev/sda5                               partition	998396		121540		-2
Filename				Type		Size		Used		Priority
/dev/sda5                               partition	998396		116604		-2
```

If you turn the swapping off with [swapoff][ref_swapoff], the tool will be OOM-killed.
```
sudo swapoff -a
```

[ref_swapoff]:https://linux.die.net/man/8/swapoff

```
2022/09/10 06:32:38 heap 0 mb, sys 218 mb
2022/09/10 06:32:39 allocate 200MB of memory
Killed
```

# overlayfs 

The last thing I looked at is the overlay file system, underlying volumes in Docker.  The [overlay file system][ref_overlay_fs] allows logically merging of different mount points. You can overlay part of a parent file system with the forked file system.  You can check the overlayfs with the following:

[ref_overlay_fs]:https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html

[40-overlayfs.sh][ref_40_overlayfs]
```
#!/bin/bash

set -eux  

sudo mkdir -p /upper /lower /work /merged
sudo chmod 777 /upper /lower /work /merged
echo 'upper foo' > /upper/foo
echo 'upper bar' > /upper/bar
echo 'lower bar' > /lower/bar
echo 'lower quux' > /lower/quux
sudo mount -t overlay overlay -olowerdir=/lower,upperdir=/upper,workdir=/work /merged 
```


See how the /merged directory holds the content of both upper and lower directory, where "upper wins" if there are files with similar names:

```
dev@debian:~/no-docker$ tail -n+1 /merged/*
==> /merged/bar <==
upper bar

==> /merged/foo <==
upper foo

==> /merged/quux <==
lower quux
```

Worth noting that the workdir is a "technical" directory used by overlayfs to prepare files to move them in a single atomic operation.

[ref_workdir]:https://unix.stackexchange.com/questions/324515/linux-filesystem-overlay-what-is-workdir-used-for-overlayfs

# Conclusion

Docker itself is not magic, the mechanisms of the kernel are the magic, and you can easily explore those mechanisms yourself. The one important part I didn't cover here is the networking namespace.  

[ref_00_prepare_sh]:https://github.com/jakub-m/no-docker/blob/main/00-prepare.sh
[ref_10_busybox_image]:https://github.com/jakub-m/no-docker/blob/main/10-busybox-image.sh
[ref_tool_go]:https://github.com/jakub-m/no-docker/blob/main/tool.go
[ref_20_unshare]:https://github.com/jakub-m/no-docker/blob/main/20-unshare.sh
[ref_40_overlayfs]:https://github.com/jakub-m/no-docker/blob/main/40-overlayfs.sh

([on HN](https://news.ycombinator.com/item?id=32794900))
