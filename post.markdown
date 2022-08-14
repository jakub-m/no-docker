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

# namespace magic

[unshare][ref_unshare] allows to specify different namespaces.  [Linux namespaces][ref_namespaces] create a separate "view" on Linux resources, such that one process can see the resources differntly that other resources. The recources can be process ids, filesystem mount points, network stack, and other.

[ref_namespaces]:https://en.wikipedia.org/wiki/Linux_namespaces


Lets explore some of those.

## pid namespace

From [Wiki][ref_pid_namespace]:

_The PID namespace provides processes with an independent set of process IDs (PIDs) from other namespaces. PID namespaces are nested, meaning when a new process is created it will have a PID for each namespace from its current namespace up to the initial PID namespace. Hence the initial PID namespace is able to see all processes, albeit with different PIDs than other namespaces will see processes with._

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

# cgroups




[ref_linux_namespaces]:https://man7.org/linux/man-pages/man7/namespaces.7.html

