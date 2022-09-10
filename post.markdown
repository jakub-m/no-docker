I wrote this post trying learning how [Docker][ref_docker] works under the hood. My learning goal was to run a Docker image without Docker.

[ref_docker]:https://en.wikipedia.org/wiki/Docker_(software)

tl;dr: Surprisingly, Docker is not magic. Docker uses Linux cgroups, namespaces, overlayfs and other Linux mechanisms. Below I try to use those mechanisms by hand.

To reproduce the learning steps, clone [no-docker git repo][ref_no_docker] and follow the post and run the scripts.  I used Debian run from VirtualBox. Start with running [00-prepare.sh][ref_00_prepare_sh] to install all the dependencies and build a small [`tool` in Go][ref_tool_go] that we will use for experimenting.

[ref_no_docker]:https://github.com/jakub-m/no-docker
[ref_00_prepare_sh]:./00-prepare.sh
[ref_so_pull]:https://stackoverflow.com/a/47624649
[ref_script_pull]:https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh

# Docker image

Let's download and un-archive [busybox image][ref_busybox] by running [10-busybox-image.sh](./10-busybox-image.sh).  You can see that a Docker image is just a nested tar archive:

[ref_busybox]:https://hub.docker.com/_/busybox
[ref_tool_go]:TOOD


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

[Linux namespaces][ref_namespaces] create a separate "view" on Linux resources, such that one process can see the resources differently that other resources. The resources can be PIDs, file system mount points, network stack, and other.  Let's see how isolating and nesting PIDs looks in practice with PID [namespace][ref_pid_namespace].

[ref_namespaces]:https://en.wikipedia.org/wiki/Linux_namespaces

[ref_pid_namespace]:https://en.wikipedia.org/wiki/Linux_namespaces#Process_ID_(pid)

[unshare][ref_unshare] system call and a command allows to set separate namespace for a process. Run [20-unshare.sh](./20-unshare.sh) to fork a shell from busybox with a separate PID namespace, with separate file system root. 

Have a look around. You will see that the root directory of the forked process is restricted ("jailed") to the directory we specified when forking the shell. Now run the `tool` and see how the same process looks from the "inside" and "outside" of the forked shell. First copy the tool to XXX, then run the tool from the forked shell:

```
# Run from the forked shell.  It does nothing but sleep.

./tool -hang hello &
```

Restricting directory tree of a process to a subdirectory is done with [chroot][ref_chroot]. You can check the actual root directory by checking /proc/\*/root of processes:

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

While namespaces isolate resources, [cgroups (control groups)][ref_cgroup] put limits on those resources. You can find the control group of our hanged tool with the following, run from the parent shell:

```
dev@debian:~$ cat /proc/$(pidof tool)/cgroup
0::/user.slice/user-1000.slice/session-92.scope
```

[ref_cgroup]:https://docs.kernel.org/admin-guide/cgroup-v2.html

Let's now use cgroups to see how we can cap memory of the forked shell.

First, find the file controlling the maximum memory of the "tool" process:

```
find /sys/fs/cgroup/ | grep $( cat /proc/$(pidof sh)/cgroup | cut -d/ -f 2-) | grep memory.max
/sys/fs/cgroup/user.slice/user-1000.slice/session-92.scope/memory.max
```

"/sys/fs/cgroup" is a mount point for cgroups file system:

```
mount | grep cgroup
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot)
```

["memory.max"][ref_memory_max] is a memory usage hard limit in memory controller, that causes OOM when memory usage cannot be reduced (more about it in a while).


[ref_memory_max]:https://facebookmicrosites.github.io/cgroup2/docs/memory-controller.html

<!-- HERE -->

Let's put 200MB limit:

```
sudo sh -c 'echo 200m > /sys/fs/cgroup/user.slice/user-1000.slice/session-4.scope/memory.max'
```



```
cat /sys/fs/cgroup/user.slice/user-1000.slice/session-4.scope/memory.events

low 0
high 0
max 3534 << this changes when you run over the max limit
oom 0
oom_kill 0
 ```

```
sudo swapoff -a
```

```
./tool -mb 200
2022/08/14 21:45:40 allocate 200MB of memory
Killed
```

[ref_linux_namespaces]:https://man7.org/linux/man-pages/man7/namespaces.7.html


# overlayfs 

[Overlay Filesystem][ref_overlay_fs] allows logically merging different mount points differrn 

[ref_overlay_fs]:https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html

[ref_workdir]:https://unix.stackexchange.com/questions/324515/linux-filesystem-overlay-what-is-workdir-used-for-overlayfs

# Conclusion
no magic
mechanisms that yuo can explore yourself 
Missing networking.
