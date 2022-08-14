I wrote this post trying learning how [Docker][ref_docker] works under the hood. My learning goal was to run a Docker image without Docker.

[ref_docker]:https://en.wikipedia.org/wiki/Docker_(software)

tl;dr: Docker is not magic, its all namespaces and cgroups!

To reproduce the learning steps, you can clone [no-docker git repo][ref_no_docker], follow the post and run the scripts.

[ref_no_docker]:https://github.com/jakub-m/no-docker

First run [`00-prepare.sh`][ref_00_prepare_sh] to install all the dependencies.  The [`download-frozen-image-v2.sh`] script to download docker images was taken from [here][ref_script_pull] ([SO][ref_so_pull]).

[ref_00_prepare_sh]:./00-prepare.sh

[ref_so_pull]:https://stackoverflow.com/a/47624649
[ref_script_pull]:https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh

A Docker image is just a nested tar archive. Let's download and unarchive [busybox image][ref_busybox].

[ref_busybox]:https://hub.docker.com/_/busybox

[10-busybox-image.sh][ref_10_busybox_image_sh]

[ref_10_busybox_image_sh]:./10-busybox-image.sh

Docker is based on Linux namespaces and cgroups (and other technologies). Below I poke them one by one.

# namespace magic

[unshare][ref_unshare] allows to specify different namespaces.  [Linux namespaces][ref_namespaces] create a separate "view" on Linux resources, such that one process can see the resources differntly that other resources. The recources can be process ids, filesystem mount points, network stack, and other.

[ref_namespaces]:https://en.wikipedia.org/wiki/Linux_namespaces

_The **PID namespace** provides processes with an independent set of process IDs (PIDs) from other namespaces. PID namespaces are nested, meaning when a new process is created it will have a PID for each namespace from its current namespace up to the initial PID namespace. Hence the initial PID namespace is able to see all processes, albeit with different PIDs than other namespaces will see processes with._

[ref_pid_namespace]:https://en.wikipedia.org/wiki/Linux_namespaces#Process_ID_(pid)

Let's see how isolating and nesting PIDs looks in practice.

We will have a parent process (a regular bash shell), and a forked shell with a separate PID namespace. From the parent shell and the forked shell we will spawn processes and see who the pids behave.

Open two terminals. We'll call them "host terminal" and "fork terminal".

Run the following:

```
# in host terminal
sleep 1111 &
```

```
# in fork terminal
./20-unshare.sh
# run the commands below from witin the forked process
sleep 2222 &
ps auxww | grep sleep
/ # ps auxww | grep sleep
    2 root      0:00 sleep 2222
    4 root      0:00 grep sleep
```

```
# in host terminal
ps auxww | grep sleep
dev       3012  0.0  0.0   7052   508 pts/0    S    13:42   0:00 sleep 1111
root      3013  0.0  0.0   1244     4 pts/1    S    13:43   0:00 sleep 2222
dev       3017  0.0  0.0   7932   708 pts/0    S+   13:43   0:00 grep sleep
```

See that in the host terminal you see the both `sleep` processes, and in the fork terminal you see only one `sleep` process. Also, the PIDs of the sleep 2222` process differ because of PID namespace (`unshare --pids`).


# chroot

Restricting directory tree of a process to a subdirectory is done with [`chroot`][ref_chroot]

```
sudo ls -l /proc/3013/root
lrwxrwxrwx 1 root root 0 Aug 14 15:54 /proc/3013/root -> /home/dev/no-docker/image-busybox-layer
```

[ref_chroot]:https://man7.org/linux/man-pages/man1/chroot.1.html


# cgroups


```
cat /proc/$(pidof sh)/cgroup
0::/user.slice/user-1000.slice/session-4.scope
```


[ref_cgroup]:https://docs.kernel.org/admin-guide/cgroup-v2.html



Let's find the file controlling max memory of the forked shell:

```
mount | grep cgroup
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot)
```

```
find /sys/fs/cgroup/ | grep $( cat /proc/$(pidof sh)/cgroup | cut -d/ -f 2-) | grep memory.max
/sys/fs/cgroup/user.slice/user-1000.slice/session-4.scope/memory.max
```


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
./main -mb 200
2022/08/14 21:45:40 allocate 200MB of memory
Killed
```

[ref_linux_namespaces]:https://man7.org/linux/man-pages/man7/namespaces.7.html


# limitting resources in action

# overlayfs 


