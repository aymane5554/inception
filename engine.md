# Docker Engine and Docker Runtime: Deep Technical Guide

## Table of Contents
1. [Docker Engine Architecture](#docker-engine-architecture)
2. [Container Runtime Fundamentals](#container-runtime-fundamentals)
3. [Deep Dive into Components](#deep-dive-into-components)
4. [Runtime Execution Flow](#runtime-execution-flow)
5. [Advanced Topics](#advanced-topics)
6. [Q&A Section](#qa-section)

---

## Docker Engine Architecture

### **High-Level Overview**

```
┌────────────────────────────────────────────────────────┐
│                    Docker Engine                        │
├────────────────────────────────────────────────────────┤
│  Docker CLI (docker command)                           │
│  ├─ Parses commands                                    │
│  └─ Communicates via REST API                         │
└──────────────────┬─────────────────────────────────────┘
                   │ (REST API over Unix socket)
                   │ /var/run/docker.sock
                   ▼
┌────────────────────────────────────────────────────────┐
│            Docker Daemon (dockerd)                      │
│  [Master process - runs as root]                       │
├────────────────────────────────────────────────────────┤
│  1. API Server (REST API handler)                      │
│  2. Container Manager                                  │
│  3. Image Manager                                      │
│  4. Network Manager                                    │
│  5. Storage Manager                                    │
│  6. Volume Manager                                     │
└──────────────────┬─────────────────────────────────────┘
                   │ (gRPC)
                   ▼
┌────────────────────────────────────────────────────────┐
│          containerd (Container Daemon)                  │
│  [Manages container lifecycle]                         │
├────────────────────────────────────────────────────────┤
│  • Image pulling/storage                               │
│  • Container creation                                  │
│  • Container lifecycle management                      │
│  • Snapshot management                                 │
└──────────────────┬─────────────────────────────────────┘
                   │ (API)
                   ▼
┌────────────────────────────────────────────────────────┐
│    runc (OCI Runtime)                                   │
│  [Low-level container runtime]                         │
├────────────────────────────────────────────────────────┤
│  • Creates/starts/stops containers                     │
│  • Manages cgroups                                     │
│  • Manages namespaces                                  │
│  • Manages Linux kernel interfaces                     │
└──────────────────┬─────────────────────────────────────┘
                   │ (System calls)
                   ▼
┌────────────────────────────────────────────────────────┐
│         Linux Kernel                                    │
│  ├─ Namespaces (PID, Network, IPC, UTS, Mount)        │
│  ├─ cgroups (CPU, Memory, Disk I/O, Devices)          │
│  ├─ Union File System (overlay2, aufs)                 │
│  └─ Network (iptables, bridge, veth)                   │
└────────────────────────────────────────────────────────┘
```

---

## **Component Details**

### **1. Docker CLI**

```bash
$ docker run -d --name mycontainer -m 512m ubuntu:20.04

# What happens:
# 1. CLI parses command
# 2. Validates arguments
# 3. Constructs API request
# 4. Sends to dockerd via /var/run/docker.sock
# 5. Receives response
# 6. Displays output to user
```

**Communication Protocol:**

```
CLI Request:
POST /containers/create HTTP/1.1
Content-Type: application/json

{
  "Image": "ubuntu:20.04",
  "Memory": 536870912,
  "Hostname": "mycontainer",
  "Cmd": ["/bin/bash"],
  "AttachStdin": false,
  "AttachStdout": true,
  "AttachStderr": true,
  "Tty": false,
  "OpenStdin": false,
  "StdinOnce": false
}

Docker Daemon Response:
HTTP/1.1 201 Created
Content-Type: application/json

{
  "Id": "e90e8dcd6e...",
  "Warnings": []
}
```

### **2. Docker Daemon (dockerd)**

**Process Tree:**

```bash
$ ps aux | grep docker

root        1234  0.5  2.3 123456 789012 ?  Ssl  10:00  0:45 /usr/bin/dockerd
root        1235  0.1  0.8  45678  12345 ?  Ssl  10:00  0:05 containerd --config /etc/containerd/config.toml
root        1236  0.0  0.2  12345  3456  ?  S    10:00  0:01 containerd-shim -namespace moby -id abc123...
```

**Configuration File:**

```json
// /etc/docker/daemon.json
{
  "debug": false,
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "insecure-registries": [],
  "registry-mirrors": [],
  "userland-proxy": true,
  "experimental": false,
  "metrics-addr": "0.0.0.0:9323",
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 5
}
```

**Responsibilities:**

1. **API Server** - Listens on Unix socket or TCP
2. **Image Management** - Pull, build, store images
3. **Container Management** - Create, start, stop, delete
4. **Network Management** - Create networks, manage connectivity
5. **Volume Management** - Create, mount volumes
6. **Event Logging** - Record container/image events

### **3. containerd**

**What is it?**

```
containerd is an industry-standard container runtime.
It's been extracted from Docker and is now a CNCF project.

Role: Bridge between Docker and OCI runtimes
```

**Architecture:**

```
Docker Daemon
    ↓ (gRPC)
containerd
├─ Content Store (stores blobs/images)
├─ Metadata Store (layer info, containers)
├─ Snapshot Drivers
│  ├─ overlay
│  ├─ aufs
│  ├─ btrfs
│  ├─ fuse-overlayfs
│  └─ native
├─ Task Service (container lifecycle)
├─ Services
│  ├─ Snapshot Service
│  ├─ Content Service
│  ├─ Leases Service
│  └─ Introspection Service
└─ Plugins
   ├─ OCI Runtimes (runc, crun, etc.)
   ├─ Snapshots
   └─ Diffing
```

**Example: containerd in action**

```bash
# List containerd containers
$ ctr container list
CONTAINER    IMAGE    RUNTIME
abc123       ubuntu   io.containerd.runc.v2

# Work with images via containerd
$ ctr images list
REF                                TYPE                                      SIZE
docker.io/library/ubuntu:20.04    application/vnd.docker.distribution.manifest.v2+json 77.8 MiB

# Pull image
$ ctr images pull docker.io/library/alpine:latest

# Create container
$ ctr container create docker.io/library/alpine:latest mycontainer
```

### **4. runc (OCI Runtime)**

**What is OCI?**

```
Open Container Initiative - standardized container spec.

Defines:
1. Runtime Specification - how to run containers
2. Image Specification - image format and layout
3. Distribution Specification - how to distribute images
```

**runc Architecture:**

```c
// Simplified runc flow
runc create <container-id>
  ├─ Parse OCI bundle
  ├─ Read config.json
  ├─ Setup cgroups
  │  ├─ Create cgroup hierarchy
  │  └─ Set resource limits
  ├─ Setup namespaces
  │  ├─ Unshare PID namespace
  │  ├─ Unshare network namespace
  │  ├─ Unshare mount namespace
  │  ├─ Unshare IPC namespace
  │  └─ Unshare UTS namespace
  ├─ Setup rootfs
  │  ├─ Mount filesystem
  │  ├─ Pivot to new root
  │  └─ Mount special filesystems
  ├─ Setup networking
  ├─ Fork container process
  └─ Return container status

runc start <container-id>
  ├─ Connect to container
  └─ Resume process from fork point

runc exec <container-id> <command>
  ├─ Enter container's namespaces
  └─ Execute command in that context
```

**OCI Bundle Structure:**

```
bundle/
├─ config.json           # OCI runtime config
├─ runtime.json          # Runtime-specific (optional)
└─ rootfs/               # Container filesystem
   ├─ bin/
   ├─ etc/
   ├─ lib/
   ├─ usr/
   ├─ var/
   └─ ... (everything in container)
```

**Example config.json:**

```json
{
  "ociVersion": "1.0.2",
  "process": {
    "terminal": false,
    "user": {
      "uid": 0,
      "gid": 0
    },
    "args": ["/bin/sh"],
    "env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "TERM=xterm"
    ],
    "cwd": "/"
  },
  "root": {
    "path": "rootfs",
    "readonly": false
  },
  "hostname": "mycontainer",
  "mounts": [
    {
      "destination": "/proc",
      "type": "proc",
      "source": "proc"
    },
    {
      "destination": "/sys",
      "type": "sysfs",
      "source": "sysfs"
    }
  ],
  "linux": {
    "resources": {
      "memory": {
        "limit": 536870912
      },
      "cpu": {
        "quota": 100000,
        "period": 100000
      }
    },
    "namespaces": [
      {"type": "pid"},
      {"type": "network"},
      {"type": "ipc"},
      {"type": "uts"},
      {"type": "mount"}
    ],
    "capabilities": {
      "bounding": [
        "CAP_CHOWN",
        "CAP_DAC_OVERRIDE",
        "CAP_SETFCAP"
      ],
      "effective": [...],
      "permitted": [...],
      "ambient": []
    }
  }
}
```

---

## Container Runtime Fundamentals

### **What is a Container Runtime?**

```
A container runtime is software that executes containers.

Responsibilities:
1. Create isolated process environments
2. Set up namespaces
3. Apply resource limits via cgroups
4. Mount filesystems
5. Setup networking
6. Manage the container lifecycle
```

### **Runtime Specifications**

**High-Level Runtime:**

```
Docker engine uses high-level runtime:
├─ Full container lifecycle management
├─ Image management
├─ Networking
├─ Storage
└─ API
```

**Low-Level Runtime:**

```
runc is the low-level runtime:
├─ Just creates and runs processes
├─ Expects OCI bundle
├─ No image management
└─ No networking (handled by high-level runtime)
```

### **Runtime Hierarchy**

```
┌─────────────────────────────────┐
│  High-Level Runtime (containerd) │
│  - Image pull/store              │
│  - Container create/delete       │
│  - Network setup                 │
│  - Volume management             │
└──────────────┬──────────────────┘
               │ Calls
               ▼
┌─────────────────────────────────┐
│  Low-Level Runtime (runc)        │
│  - Namespace setup               │
│  - cgroup limits                 │
│  - Process isolation             │
│  - Capability management         │
└──────────────┬──────────────────┘
               │ Uses
               ▼
┌─────────────────────────────────┐
│  Linux Kernel                   │
│  - Namespaces                   │
│  - cgroups                      │
│  - Virtual filesystems          │
│  - Networking                   │
└─────────────────────────────────┘
```

### **Alternative Runtimes**

```
Docker can use different OCI runtimes:

1. runc (default, most common)
   ├─ Written in Go
   ├─ Standard implementation
   └─ Most compatible

2. crun (alternative)
   ├─ Written in C
   ├─ Faster startup
   ├─ Lower memory footprint
   └─ Good for edge/IoT

3. kata-runtime (security-focused)
   ├─ Lightweight VMs per container
   ├─ Stronger isolation
   ├─ Kernel bypass isolation
   └─ Overhead: slower, more memory

4. gVisor (sandbox runtime)
   ├─ User-space kernel
   ├─ Reduced attack surface
   └─ Significant overhead
```

**Configuration:**

```json
// /etc/docker/daemon.json
{
  "runtimes": {
    "runc": {
      "path": "runc",
      "runtimeArgs": []
    },
    "crun": {
      "path": "/usr/bin/crun",
      "runtimeArgs": []
    },
    "kata": {
      "path": "/usr/bin/kata-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "runc"
}
```

---

## Deep Dive into Components

### **1. Namespaces in Depth**

#### **PID Namespace (Process Isolation)**

```bash
# Host perspective
$ ps aux
UID     PID  COMMAND
root    1    /init (systemd)
root    100  /usr/bin/dockerd
user    200  /bin/bash
container_proc  300  /bin/bash  (inside container)
container_proc  301  sleep 1000 (inside container)

# Container perspective
$ ps aux (inside container)
UID     PID  COMMAND
root    1    /bin/bash (looks like PID 1)
root    2    sleep 1000

# The container process has PID 300 on host but PID 1 in container!
```

**Implementation:**

```c
// How runc creates PID namespace
int clone_flags = CLONE_NEWPID;
pid_t child = clone(container_main, stack, clone_flags, NULL);

// Now child sees itself as PID 1
```

**Benefits:**
```
1. Process isolation - can't see/kill host processes
2. Clean PID space - container sees PID 1 as init
3. Signal handling - signals not cross boundaries
4. Process hierarchy - independent from host
```

#### **Network Namespace (Network Isolation)**

```
Host network:
eth0: 10.0.0.5
lo: 127.0.0.1

Container 1 network:
veth1: 172.17.0.2
lo: 127.0.0.1

Container 2 network:
veth2: 172.17.0.3
lo: 127.0.0.1

Connection:
Container 1 port 80
└─ docker bridge (br-xxx) (172.17.0.1)
   └─ Container 2 port 80

External:
Host port 8080 (iptables rule)
└─ docker bridge (192.168.1.100:8080 → 172.17.0.2:80)
   └─ Container 1 port 80
```

**Network Setup Process:**

```bash
# 1. Create veth pair
ip link add veth1 type veth peer name veth1-br

# 2. Move veth into container namespace
ip link set veth1 netns <container-pid>

# 3. Configure inside container
nsenter -n -t <container-pid> ip addr add 172.17.0.2/16 dev veth1
nsenter -n -t <container-pid> ip link set veth1 up

# 4. Connect to bridge
brctl addif docker0 veth1-br
ip link set veth1-br up

# 5. Setup port mapping (iptables)
iptables -t nat -A DOCKER -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
```

#### **Mount Namespace (Filesystem Isolation)**

```
Host filesystem:
/
├─ /home
├─ /var
├─ /usr
├─ /etc
└─ ... (full filesystem)

Container 1 filesystem:
/  (rootfs from image, layered)
├─ /bin
├─ /etc
├─ /home
└─ /var

Container 2 filesystem:
/  (different rootfs)
├─ /bin
├─ /etc
└─ ... (independent filesystem)

Changes in container don't affect:
- Host filesystem
- Other containers
- Mounted volumes (unless explicitly shared)
```

**Mount Setup:**

```bash
# 1. Create container root
mount -t overlay overlay \
  -o lowerdir=base_layer,upperdir=container_layer,workdir=work_dir \
  container_root

# 2. Enter container namespace
nsenter -m -t <container-pid>

# 3. Pivot root (change filesystem perspective)
pivot_root container_root old_root
umount -l old_root

# Now container sees container_root as /
```

#### **IPC Namespace (Inter-Process Communication)**

```
Host IPC:
├─ Shared memory segments
├─ Message queues
└─ Semaphores

Container 1 IPC:
├─ Isolated shared memory
├─ Isolated message queues
└─ Isolated semaphores

Container 2 IPC:
├─ Isolated shared memory
├─ Isolated message queues
└─ Isolated semaphores

Containers can't:
- Access each other's shared memory
- Send messages between containers
- Interfere with each other's IPC
```

**Use Case:**

```bash
# Two processes in same container communicating
# This works (same IPC namespace)
Process 1: shmget(key, size, IPC_CREAT)
Process 2: shmget(key, size, 0)
# They can share memory

# Container 1 and Container 2 trying to communicate
# This fails (different IPC namespaces)
Container1: shmget(key, size, IPC_CREAT)
Container2: shmget(key, size, 0)
# Container2 can't see Container1's shared memory
```

#### **UTS Namespace (Hostname/Domain)**

```
Host:
hostname: myserver.example.com
domainname: example.com

Container 1:
hostname: container-1
domainname: localdomain
(changes don't affect host)

Container 2:
hostname: container-2
domainname: localdomain
(independent from Container 1)

Inside container:
$ hostname
container-1
$ domainname
localdomain
```

#### **User Namespace (User ID Mapping)**

```
Host UIDs:
UID 0: root
UID 1000: alice
UID 1001: bob

Container perspective (with user namespace):
UID 0: container root (actually UID 100000 on host)
UID 1: container user (actually UID 100001 on host)

File ownership mapping:
Inside: chown file root (UID 0)
Host:   ls -l shows UID 100000 (not root!)
Host:   Can't modify even as root (UID mapping prevents it)

Security benefit:
- Container root ≠ host root
- Compromise limited to container
- No privilege escalation to host
```

### **2. cgroups (Control Groups) in Depth**

#### **Memory cgroup**

```bash
# Create cgroup hierarchy
mkdir -p /sys/fs/cgroup/memory/docker/container-abc123

# Set memory limit (512 MB)
echo 536870912 > /sys/fs/cgroup/memory/docker/container-abc123/memory.limit_in_bytes

# Move process into cgroup
echo <PID> > /sys/fs/cgroup/memory/docker/container-abc123/cgroup.procs

# Monitor memory usage
cat /sys/fs/cgroup/memory/docker/container-abc123/memory.usage_in_bytes
# Output: 245678901 (245 MB used)

# If process exceeds limit:
# 1. First: Try to reclaim cache
# 2. Then: Try to swap (if enabled)
# 3. Finally: OOM-kill process

# Watch OOM events
cat /sys/fs/cgroup/memory/docker/container-abc123/memory.oom_control
# oom_kill_disable 0 (killing enabled)
# under_oom 0 (not under OOM)
```

**Memory cgroup v2 (newer):**

```bash
# cgroup v2 unified hierarchy
/sys/fs/cgroup/docker/container-abc123/

# Set memory limit
echo "512M" > /sys/fs/cgroup/docker/container-abc123/memory.max

# Monitor
cat /sys/fs/cgroup/docker/container-abc123/memory.current
cat /sys/fs/cgroup/docker/container-abc123/memory.stat
```

#### **CPU cgroup**

```bash
# Create cgroup
mkdir -p /sys/fs/cgroup/cpu/docker/container-abc123

# Set CPU limit (50% of 1 core = 50000/100000)
echo 50000 > /sys/fs/cgroup/cpu/docker/container-abc123/cpu.cfs_quota_us
echo 100000 > /sys/fs/cgroup/cpu/docker/container-abc123/cpu.cfs_period_us

# Explanation:
# cfs_quota_us: 50000 microseconds
# cfs_period_us: 100000 microseconds (100ms)
# Result: 50ms out of every 100ms = 50% CPU

# Set CPU affinity (use only CPU 0 and 1)
echo "0-1" > /sys/fs/cgroup/cpu/docker/container-abc123/cpuset.cpus

# Set CPU shares (relative CPU allocation)
echo 1024 > /sys/fs/cgroup/cpu/docker/container-abc123/cpu.shares
# All containers with 1024 shares get equal CPU
```

#### **Block I/O cgroup**

```bash
# Create cgroup
mkdir -p /sys/fs/cgroup/blkio/docker/container-abc123

# Get device major:minor number
$ ls -l /dev/sda
brw-rw---- 1 root disk 8, 0 Nov 15 10:00 /dev/sda
# Major: 8, Minor: 0

# Limit read rate to 1 MB/sec (1048576 bytes)
echo "8:0 1048576" > /sys/fs/cgroup/blkio/docker/container-abc123/blkio.throttle.read_bps_device

# Limit write rate to 1 MB/sec
echo "8:0 1048576" > /sys/fs/cgroup/blkio/docker/container-abc123/blkio.throttle.write_bps_device

# Monitor I/O statistics
cat /sys/fs/cgroup/blkio/docker/container-abc123/blkio.throttle.io_service_bytes
# Output:
# 8:0 Read 123456789
# 8:0 Write 987654321
```

#### **PIDs cgroup**

```bash
# Limit max processes to 200
echo 200 > /sys/fs/cgroup/pids/docker/container-abc123/pids.max

# Monitor current count
cat /sys/fs/cgroup/pids/docker/container-abc123/pids.current
# Output: 15

# If process tries to fork beyond limit:
# fork() fails with EAGAIN (Too many processes)
```

#### **Device cgroup**

```bash
# Deny all devices by default
echo "a *:* m" > /sys/fs/cgroup/devices/docker/container-abc123/devices.deny

# Allow specific devices
echo "c 1:3 rw" > /sys/fs/cgroup/devices/docker/container-abc123/devices.allow
# c: character device
# 1:3: /dev/null (major:minor)
# rw: read + write

echo "c 1:5 rw" > ... # /dev/zero
echo "c 1:8 rw" > ... # /dev/random
echo "b 8:0 rm" > ... # /dev/sda (block device, read + mknod)
```

#### **Freezer cgroup**

```bash
# Pause all processes in cgroup
echo "FROZEN" > /sys/fs/cgroup/freezer/docker/container-abc123/freezer.state
# All processes instantly stop (frozen state)

# Resume processes
echo "THAWED" > /sys/fs/cgroup/freezer/docker/container-abc123/freezer.state
# All processes resume from where they were

# Use case:
# docker pause <container>  # Uses freezer cgroup
```

### **3. Union File System (UnionFS) in Depth**

#### **OverlayFS Architecture**

```
Docker Image Layers:
├─ Base layer (from: ubuntu:20.04)
│  ├─ bin/
│  ├─ etc/
│  ├─ lib/
│  ├─ usr/
│  └─ var/
│
├─ Layer 2 (RUN apt-get update && apt-get install nginx)
│  ├─ etc/nginx/
│  ├─ usr/sbin/nginx
│  └─ var/www/
│
└─ Layer 3 (ADD app.conf /etc/nginx/)
   └─ etc/nginx/app.conf

Container writable layer (upperdir):
├─ etc/ (modified from base)
│  ├─ nginx/
│  │  └─ app.conf (newly added)
│  └─ hostname (modified, shadows base layer)
└─ var/ (modified)
   └─ log/ (newly created)


Unified view (what container sees):
/
├─ bin/          (from base layer)
├─ etc/          (merged: base + layer2 + layer3 + upperdir)
│  ├─ hostname   (from upperdir)
│  ├─ nginx/     (from layer3)
│  └─ other/     (from base)
├─ lib/          (from base layer)
├─ usr/          (merged: base + layer2)
│  ├─ sbin/nginx (from layer2)
│  └─ bin/       (from base)
└─ var/          (merged: base + layer3 + upperdir)
   ├─ log/       (from upperdir)
   ├─ www/       (from layer3)
   └─ cache/     (from base)
```

**How OverlayFS Works:**

```
1. Read operation:
   /etc/hostname
   ├─ Check upperdir (container layer): NOT FOUND
   ├─ Check layer3: NOT FOUND
   ├─ Check layer2: NOT FOUND
   ├─ Check base layer: FOUND → Read from base
   └─ Return to application

2. Write operation:
   File: /usr/bin/bash (original in base layer)
   Action: Modify bash
   ├─ Copy file from base layer to upperdir (Copy-on-Write)
   ├─ Modify the copy in upperdir
   ├─ Application sees modified version
   ├─ Base layer remains unchanged
   └─ Disk: reads optimized upperdir

3. Delete operation:
   File: /var/log/old.log (exists in layer2)
   Action: Delete file
   ├─ Create "whiteout" file in upperdir
   ├─ whiteout file marks that this path is deleted
   ├─ OverlayFS hides deleted file
   ├─ Lower layers not modified
   └─ On container delete: everything removed
```

**Performance Characteristics:**

```
Read path (first time):
└─ Fast (reads directly from optimal layer)

Read path (frequently read from lower layers):
└─ Slower (kernel must traverse layers)
   └─ Can be optimized with caching

Write path:
├─ Copy-on-Write overhead (first write)
├─ Subsequent writes fast
└─ No impact on lower layers (copy isolated)

Delete path:
└─ Just creates marker, very fast

Space efficiency:
└─ Multiple containers share base layers
   └─ 1 base layer (1 GB) + 100 containers
   └─ Only 1 copy of base, 100 small upperdir layers
   └─ Much more efficient than full copy per container
```

**Layer Stacking Example:**

```dockerfile
# Dockerfile
FROM ubuntu:20.04              # Layer 0: 77 MB
RUN apt-get update             # Layer 1: 50 MB (diff from layer 0)
RUN apt-get install -y nginx   # Layer 2: 45 MB (diff from layer 1)
RUN mkdir -p /app              # Layer 3: 1 KB (tiny diff)
COPY app.py /app/              # Layer 4: 10 KB (app files)
```

**Image size analysis:**

```
Total uncompressed:
77 + 50 + 45 + 1 + 10 = 183 MB (if summed)

Actual on disk:
Each container only stores the diff (delta), not full copy

Container 1:
├─ Base layer 0 (referenced, not copied)
├─ Layer 1 (delta stored)
├─ Layer 2 (delta stored)
├─ Layer 3 (delta stored)
├─ Layer 4 (delta stored)
└─ Upperdir (writable layer for container runtime)

Container 2 (same image):
├─ Base layer 0 (shared with Container 1!)
├─ Layer 1 (shared)
├─ Layer 2 (shared)
├─ Layer 3 (shared)
├─ Layer 4 (shared)
└─ Upperdir (separate, only for Container 2 changes)

Result:
- Container 1: ~183 MB image + small upperdir layer
- Container 2: ~183 MB image (SHARED!) + small upperdir layer
- Total: ~183 MB + 2 × upperdirs (instead of 2 × 183 MB)
```

### **4. Docker Storage Driver in Depth**

```bash
# View storage driver
$ docker info | grep "Storage Driver"
Storage Driver: overlay2

# Check storage location
$ docker info | grep "Docker Root Dir"
Docker Root Dir: /var/lib/docker

# Examine storage structure
$ ls -la /var/lib/docker/overlay2/
total 12
drwx------  3 root root 4096 Jan 15 10:00 .
drwx------  8 root root 4096 Jan 15 10:00 ..
-rw-------  1 root root 1024 Jan 15 10:00 l
drwx--S--- 19 root root 4096 Jan 15 10:00 abcd1234...
drwx--S--- 19 root root 4096 Jan 15 10:00 efgh5678...
```

**Overlay2 Directory Structure:**

```
/var/lib/docker/overlay2/
├─ l/                    (symlink layer directory)
│  ├─ ABC123 → ../abcd1234/layer
│  ├─ DEF456 → ../efgh5678/layer
│  └─ ... (short names for easier iptables rules)
│
├─ abcd1234/             (image layer)
│  ├─ link               (short name: ABC123)
│  └─ layer/             (actual layer content)
│     ├─ etc/
│     ├─ usr/
│     └─ var/
│
├─ efgh5678+base/        (container layer)
│  ├─ link               (short name: DEF456)
│  ├─ lower              (references to lower layers)
│  ├─ merged/            (unified view of all layers)
│  ├─ upper/             (writable container layer)
│  └─ work/              (OverlayFS working directory)
│     └─ (temporary files for atomic operations)
│
└─ ... (more layers)
```

**Mount Points:**

```bash
# View all mounts
$ mount | grep overlay

overlay on /var/lib/docker/overlay2/efgh5678+base/merged \
  type overlay (rw,relatime,lowerdir=...more... \
  upperdir=/var/lib/docker/overlay2/efgh5678+base/upper, \
  workdir=/var/lib/docker/overlay2/efgh5678+base/work)

# Container's root filesystem is the "merged" directory
# Application sees it as /
```

**Copy-on-Write Example:**

```bash
# Image has /usr/bin/bash (100 MB in lower layer)
# Container modifies bash

# Before modification:
$ ls -li /var/lib/docker/overlay2/lower/usr/bin/bash
123456 -rwxr-xr-x bash

$ ls -li /var/lib/docker/overlay2/efgh5678+base/upper/usr/bin/bash
# Not found (doesn't exist in upper yet)

# Container modifies bash
$ nano /usr/bin/bash  # Inside container

# After modification:
$ ls -li /var/lib/docker/overlay2/lower/usr/bin/bash
123456 -rwxr-xr-x bash  # Original unchanged

$ ls -li /var/lib/docker/overlay2/efgh5678+base/upper/usr/bin/bash
789012 -rwxr-xr-x bash  # NEW inode in upper layer!

# Container sees modified version (from upper)
# Host sees lower version unchanged
# CoW prevented: changes isolated to container
```

---

## Runtime Execution Flow

### **Complete Container Lifecycle**

```
┌──────────────────────────────────────────────────────┐
│ User: docker run -d -m 512m --name web ubuntu bash  │
└──────────────────┬───────────────────────────────────┘
                   ▼
        ┌──────────────────────┐
        │  Docker CLI Parses   │
        │  Command & Arguments │
        └──────────┬───────────┘
                   ▼
        ┌──────────────────────────────────────┐
        │ Construct API Request:               │
        │ POST /containers/create              │
        │ {                                    │
        │   "Image": "ubuntu",                 │
        │   "Cmd": ["bash"],                   │
        │   "Memory": 536870912,               │
        │   "Hostname": "web"                  │
        │ }                                    │
        └──────────┬───────────────────────────┘
                   │ (REST API over Unix socket)
                   │ /var/run/docker.sock
                   ▼
        ┌──────────────────────────────────────────┐
        │  Docker Daemon Receives Request          │
        │  (dockerd process)                       │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ 1. Image Manager                         │
        │    ├─ Check if ubuntu exists locally     │
        │    ├─ If not, pull from registry         │
        │    └─ Get all layers for image           │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ 2. Call containerd via gRPC              │
        │    CreateContainer request               │
        └──────────┬───────────────────────────────┘
                   │ (gRPC)
                   ▼
        ┌──────────────────────────────────────────┐
        │  containerd Receives Request             │
        │  (containerd process)                    │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ 1. Snapshot Manager                      │
        │    ├─ Create container snapshot          │
        │    ├─ Setup layer stack (lowerdir)       │
        │    └─ Prepare for OverlayFS              │
        │                                          │
        │ 2. Create OCI Bundle                     │
        │    ├─ Generate config.json               │
        │    ├─ Set cgroup limits                  │
        │    ├─ Set namespaces                     │
        │    └─ Prepare rootfs reference           │
        │                                          │
        │ 3. Prepare Metadata                      │
        │    ├─ Store container metadata           │
        │    └─ Generate container ID              │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ Return to Docker Daemon                  │
        │ Container ID: abc123def456...            │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ Docker Daemon Responds to CLI:           │
        │ {                                        │
        │   "Id": "abc123def456...",               │
        │   "Warnings": []                         │
        │ }                                        │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ User: docker start <container>           │
        │ or combined: docker run ... (auto start)  │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ Docker Daemon: POST /containers/start    │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ containerd: Start container              │
        │ (Create task/shim)                       │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ 1. Create containerd-shim process        │
        │    (lightweight shim for this container) │
        │                                          │
        │ 2. Shim calls runc create                │
        │    └─ Prepare container environment      │
        │                                          │
        │ 3. runc executes:                        │
        │    ├─ Parse config.json                  │
        │    ├─ Create cgroups hierarchy           │
        │    ├─ Create namespaces                  │
        │    ├─ Mount filesystems                  │
        │    ├─ Setup container rootfs via Overlay │
        │    ├─ Setup capabilities                 │
        │    ├─ Fork container process (PID 1)     │
        │    └─ Container init process ready       │
        │                                          │
        │ 4. runc returns control to shim          │
        │                                          │
        │ 5. Shim: runc start                      │
        │    └─ Resume from fork point             │
        │    └─ Container process begins execution │
        │                                          │
        │ 6. Shim monitors container process       │
        │    ├─ Captures stdout/stderr             │
        │    ├─ Manages I/O                        │
        │    └─ Reports status changes             │
        └──────────┬───────────────────────────────┘
                   ▼
        ┌──────────────────────────────────────────┐
        │ Container Running!                       │
        │ └─ PID namespace: sees only own procs    │
        │ └─ Network namespace: own veth interface │
        │ └─ Mount namespace: own filesystem       │
        │ └─ IPC namespace: own IPC resources      │
        │ └─ UTS namespace: own hostname           │
        │ └─ cgroups: limited resources            │
        └──────────────────────────────────────────┘
```

---

## Q&A Section

### **Q1: What is the difference between Docker Engine and Docker Runtime?**

**A:**

Docker Engine is the **complete system** for managing containers.

Docker Runtime is the **software that actually executes containers**.

| Aspect | Docker Engine | Docker Runtime |
|--------|---------------|-----------------|
| **Scope** | Complete container platform | Low-level execution layer |
| **Components** | Docker daemon, containerd, runc, API server, etc. | Just the process execution (runc, crun, kata) |
| **Responsibilities** | Image management, networking, storage, API, orchestration | Creating namespaces, setting cgroups, forking processes |
| **Written in** | Go (Docker) | Go (runc), C (crun), etc. |
| **User-facing** | Yes (users interact with Docker Engine) | No (internal, abstracted away) |
| **Configurability** | Limited customization | Can swap between runtimes |
| **Layers** | High-level: Docker daemon → containerd → runc | Low-level: Just the OCI-compliant binary |

**Example:**

```bash
# Docker Engine handles this
docker run -d -p 8080:80 --memory 512m nginx

# Docker Engine does:
├─ Pulls image
├─ Creates container
├─ Sets up networking (port mapping)
├─ Manages storage (OverlayFS)
└─ Calls Docker Runtime to actually run

# Docker Runtime (runc) does:
├─ Creates namespaces
├─ Sets cgroups limits
├─ Mounts filesystems
├─ Forks container process
└─ Exits (shim takes over)
```

---

### **Q2: Why is containerd separate from Docker daemon?**

**A:**

**Historical Context:**

```
Before: Docker did everything
dockerd
├─ API handling
├─ Image management
├─ Container creation
├─ Network setup
├─ Runtime execution
└─ MONOLITHIC

Problems:
├─ Large process
├─ Restarts required updates to all containers
├─ Upgrades risky (daemon restart = all containers affected)
├─ Difficult to use without Docker
├─ Kubernetes wanted direct access to container runtime
```

**After: Separation of Concerns**

```
dockerd
├─ API handling
├─ Container orchestration
└─ User-facing features

containerd
├─ Image management
├─ Container lifecycle
├─ Snapshot management
└─ OCI-compliant runtime management

Benefits:
├─ Smaller processes (can restart independently)
├─ containerd is CNCF project (open governance)
├─ Kubernetes can use containerd directly
├─ Docker is just one consumer of containerd
├─ Docker updates don't require daemon restart
├─ Better resource efficiency
```

**Architecture:**

```
Kubernetes
└─ Talks directly to containerd (no Docker needed)

Docker
├─ Talks to containerd via gRPC
├─ Adds user-friendly features
└─ Orchestration layer on top

Other tools
└─ Talk to containerd directly (podman, nerdctl, etc.)
```

---

### **Q3: What happens when you run `docker run -d ubuntu sleep 1000`?**

**A:**

```
Step 1: CLI Parsing (docker run -d ubuntu sleep 1000)
├─ Command: run
├─ Flags: -d (detach mode)
├─ Image: ubuntu:latest (implicit)
├─ Command: sleep 1000
└─ Create request constructed

Step 2: Docker Daemon - Image Check
├─ Check if ubuntu:latest exists locally
├─ If not: Pull from Docker Hub
│  ├─ Authenticate (if private)
│  ├─ Get image manifest
│  ├─ Download layers (parallel, with retries)
│  ├─ Verify SHA256 checksums
│  ├─ Extract to /var/lib/docker/image/overlay2/imagedb/
│  └─ Store metadata
├─ If yes: Use existing
└─ Verify image integrity

Step 3: Docker Daemon - containerd Communication
├─ Call: containerd.CreateContainer(
│    image: "ubuntu:latest",
│    id: "<generated-id>",
│    spec: <OCI runtime spec>
│  )
└─ containerd receives request

Step 4: containerd - Snapshot Creation
├─ Create snapshot for container
│  ├─ Name: <container-id>
│  ├─ Parent: ubuntu:latest image
│  └─ Type: writable
├─ Setup layers
│  ├─ Identify all image layers
│  ├─ Create lowerdir references
│  └─ Prepare for OverlayFS
└─ Allocate disk space (upperdir)

Step 5: containerd - OCI Bundle Creation
├─ Generate config.json
│  ├─ Process spec: ["sleep", "1000"]
│  ├─ Root: reference to snapshot
│  ├─ Rootfs: set to snapshot path
│  ├─ Hostname: <random or default>
│  ├─ Environment variables
│  ├─ User: root (UID 0)
│  ├─ Working directory: /
│  ├─ Mounts
│  │  ├─ /proc (procfs)
│  │  ├─ /sys (sysfs)
│  │  ├─ /dev (devtmpfs)
│  │  └─ /dev/pts (devpts)
│  ├─ Linux: cgroups and namespace config
│  │  ├─ Namespaces: all enabled
│  │  ├─ Capabilities: bounding set
│  │  ├─ Resources:
│  │  │  ├─ Memory: unlimited (can override)
│  │  │  ├─ CPU: unlimited
│  │  │  └─ PIDs: unlimited
│  │  └─ Devices: allow common devices
│  └─ [More fields...]
├─ Store config.json in containerd metadata store
└─ Generate container ID and return

Step 6: Docker Daemon - Response
├─ Container created successfully
├─ Return container ID to CLI
└─ CLI exits (because -d flag = detach)

Step 7: User starts container (or auto-start if not -d)
├─ docker start <container>
├─ Docker daemon calls: containerd.Start(container_id)
└─ containerd receives request

Step 8: containerd - Prepare to Start
├─ Load container metadata
├─ Load snapshot for this container
├─ Prepare to create task/shim
└─ Call: runc create

Step 9: runc Create
├─ Fork new process (parent: runc, child: container-init)
├─ Parent process (runc) prepares container:
│  ├─ Parse config.json
│  ├─ Create cgroup hierarchy
│  │  ├─ /sys/fs/cgroup/memory/docker/<container>/
│  │  ├─ /sys/fs/cgroup/cpu/docker/<container>/
│  │  ├─ /sys/fs/cgroup/pids/docker/<container>/
│  │  └─ [other cgroups]
│  ├─ Set cgroup limits
│  │  ├─ memory.limit_in_bytes = unlimited
│  │  ├─ cpu.shares = 1024 (default)
│  │  └─ pids.max = unlimited
│  ├─ Setup namespaces (unshare syscall)
│  │  ├─ CLONE_NEWPID: container sees PID 1 as init
│  │  ├─ CLONE_NEWNET: isolated network namespace
│  │  ├─ CLONE_NEWIPC: isolated IPC
│  │  ├─ CLONE_NEWUTS: isolated hostname/domain
│  │  ├─ CLONE_NEWNS: isolated mount points
│  │  └─ (CLONE_NEWUSER: optional user mapping)
│  ├─ Setup rootfs
│  │  ├─ Create OverlayFS mount
│  │  │  ├─ lowerdir: image layers
│  │  │  ├─ upperdir: snapshot writable layer
│  │  │  ├─ workdir: OverlayFS temp directory
│  │  │  └─ Mount at /var/lib/docker/overlay2/<id>/merged
│  │  ├─ chroot/pivot_root to new root
│  │  └─ Change perspective: container now sees merged as /
│  ├─ Mount special filesystems
│  │  ├─ /proc: procfs
│  │  ├─ /sys: sysfs
│  │  ├─ /dev: devtmpfs
│  │  ├─ /dev/pts: devpts
│  │  ├─ /dev/shm: tmpfs
│  │  └─ /run: tmpfs
│  ├─ Setup capabilities
│  │  ├─ Keep: CAP_CHOWN, CAP_DAC_OVERRIDE, etc.
│  │  ├─ Drop: CAP_SYS_ADMIN, CAP_NET_ADMIN (usually)
│  │  └─ This prevents privilege escalation
│  ├─ Setup environment
│  │  ├─ Set LD_LIBRARY_PATH
│  │  ├─ Set PATH
│  │  ├─ Set HOME
│  │  └─ Set custom env vars
│  └─ Prepare to execute process
│
├─ Child process (container-init, PID 1 in namespace)
│  ├─ Now isolated in all namespaces
│  ├─ Can't see parent's processes
│  ├─ Can't access parent's network
│  ├─ Can't access parent's filesystem
│  ├─ Waits for signal to execute actual command
│  └─ (Currently paused, waiting for runc start)
│
└─ runc returns, keeping child process frozen

Step 10: runc Start
├─ Resume child process from pause point
├─ Child executes: execve("sleep", ["1000"], envp)
├─ Now running: PID 1 inside container (isolated)
└─ Process begins execution

Step 11: containerd Shim Takeover
├─ containerd creates shim process
├─ Shim connects to container process
├─ Shim handles:
│  ├─ stdout/stderr capture
│  ├─ Exit code collection
│  ├─ Signal forwarding (SIGTERM, SIGKILL)
│  └─ Checkpoint/restore (if supported)
├─ Parent runc process exits (its work done)
├─ Shim remains as container process PID parent
└─ (Shim is zombie until container exits)

Step 12: Container Running
├─ Process: sleep 1000
├─ PID in container namespace: 1
├─ PID on host: <assigned-pid> (e.g., 12345)
├─ Isolated:
│  ├─ Can't see host processes
│  ├─ Has own network interface (veth)
│  ├─ Has own filesystem (via OverlayFS)
│  ├─ Memory limited (if specified)
│  ├─ CPU limited (if specified)
│  └─ Can be paused/resumed
└─ Running for 1000 seconds

Step 13: Container Exit (after 1000 seconds)
├─ sleep process exits
├─ Kernel notifies shim
├─ Shim collects exit code: 0
├─ Shim reports status to containerd
├─ containerd updates metadata
├─ Docker daemon notified of state change
├─ OverlayFS unmounted
├─ cgroups removed
├─ Namespaces destroyed
└─ Container stopped

Step 14: Cleanup (docker rm)
├─ Delete container metadata
├─ Delete snapshot (upperdir)
├─ Free disk space
└─ Done
```

---

### **Q4: How does port mapping work at the network level?**

**A:**

**Setup Phase:**

```bash
$ docker run -d -p 8080:80 nginx

# Docker creates:
1. veth pair (virtual ethernet pair)
   ├─ veth12345 (container-side)
   └─ veth12345-br (bridge-side, no dash)

2. Move container-side into container namespace
   ip link set veth12345 netns <container-pid>

3. Configure inside container namespace
   nsenter -n -t <container-pid> bash
   # ip addr add 172.17.0.2/16 dev veth12345
   # ip link set veth12345 up

4. Connect bridge-side to docker bridge
   brctl addif docker0 veth12345-br
   ip link set veth12345-br up

5. Setup iptables for port mapping
   iptables -t nat -A DOCKER -p tcp --dport 8080 \
     -j DNAT --to-destination 172.17.0.2:80
```

**Runtime Behavior:**

```
User requests: http://myhost.com:8080

Network path:
1. User machine → Internet → myhost.com (192.168.1.100)
   Request: GET / HTTP/1.1
   Destination: 192.168.1.100:8080

2. Host receives packet (port 8080)
   Kernel routing table checks: What to do with port 8080?
   
3. iptables rule matches:
   PREROUTING chain (incoming packets)
   Rule: -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
   Action: Destination Network Address Translation
   
4. Kernel transforms packet:
   Original destination: 192.168.1.100:8080 (host IP)
   New destination: 172.17.0.2:80 (container IP)
   Source: unchanged (client IP)

5. Packet sent to docker0 bridge
   docker0 receives packet for 172.17.0.2:80

6. Bridge routes to veth12345-br
   veth12345-br receives packet

7. Kernel transfers to container namespace
   veth12345 receives packet (inside container)

8. Container sees packet:
   Source: client IP
   Destination: 127.0.0.1:80 or 172.17.0.2:80
   Port: 80 (mapped from 8080)
   Nginx listens on port 80
   Nginx responds

9. Response packet created:
   Source: 172.17.0.2:80 (container)
   Destination: client IP
   
10. Kernel applies reverse NAT (conntrack):
    Rule: -m conntrack --ctstate RELATED,ESTABLISHED \
          -j ACCEPT
    Knows this is related to incoming connection
    Source NAT: 172.17.0.2 → 192.168.1.100
    
11. Response returned to client
    Client sees response from 192.168.1.100:8080 ✓
```

**iptables Rules:**

```bash
# View all Docker port mappings
$ iptables -t nat -L DOCKER

Chain DOCKER (2 references)
target     prot opt source   destination
DNAT       tcp  --  anywhere anywhere  tcp dpt:8080 to:172.17.0.2:80
DNAT       tcp  --  anywhere anywhere  tcp dpt:8081 to:172.17.0.3:80

# View conntrack (connection tracking)
$ conntrack -L | grep 8080

tcp      6 118 TIME_WAIT src=192.168.1.105 dst=192.168.1.100 \
sport=54321 dport=8080 src=172.17.0.2 dst=192.168.1.105 \
sport=80 dport=54321 [ASSURED] mark=0 use=1
```

---

### **Q5: What is the difference between `docker stop` and `docker kill`?**

**A:**

| Aspect | `docker stop` | `docker kill` |
|--------|---------------|---------------|
| **Signal sent** | SIGTERM | SIGKILL |
| **Graceful** | Yes (allows cleanup) | No (immediate) |
| **Time limit** | Default 10 seconds | Immediate |
| **Container behavior** | Can handle signal, cleanup gracefully | Forcefully terminated |
| **Use case** | Normal shutdown | Unresponsive container |

**Process:**

**docker stop:**

```bash
$ docker stop mycontainer

# Process:
1. Docker daemon sends SIGTERM to PID 1 (nginx)
2. Nginx receives signal
3. Nginx logs: "Shutting down"
4. Nginx closes listening socket
5. Nginx finishes current requests
6. Nginx closes database connections
7. Nginx writes logs
8. Nginx exits cleanly
9. Container stops (exit code 143)
10. Shim reports stop to Docker daemon

# Timeline: 1-10 seconds (graceful)

# If container doesn't stop after timeout (default 10s):
# Docker automatically sends SIGKILL
```

**docker kill:**

```bash
$ docker kill mycontainer

# Process:
1. Docker daemon sends SIGKILL to PID 1 (nginx)
2. Nginx receives SIGKILL
3. Nginx CANNOT handle SIGKILL (uncatchable)
4. Kernel terminates process immediately
5. No cleanup possible
6. Requests dropped
7. Database connections abruptly closed
8. Logs incomplete
9. Process dead (exit code 137)

# Timeline: Immediate (0-1 ms)
```

**Signals:**

```bash
# SIGTERM (terminate signal)
signal.signal(signal.SIGTERM, signal_handler)
def signal_handler(signum, frame):
    print("Shutting down gracefully")
    # Close connections
    # Flush buffers
    # Save state
    sys.exit(0)

# SIGKILL (kill signal)
signal.signal(signal.SIGKILL, handler)  # ERROR!
# Can't be caught!
# Process dies immediately
# No cleanup possible
```

**Exit codes:**

```
Exit code 0: Graceful exit (docker stop)
Exit code 137: SIGKILL received (docker kill)
Exit code 143: SIGTERM received but didn't handle (docker stop timeout)
Exit code 1-125: Application error
Exit code 126: Command invoked cannot execute
Exit code 127: Command not found
Exit code 130: Process terminated by SIGINT
```

---

### **Q6: How does Docker handle networking when you connect a container to multiple networks?**

**A:**

**Setup:**

```bash
# Create networks
docker network create frontend
docker network create backend

# Create container
docker run -d --name web --network frontend nginx

# Connect to another network
docker network connect backend web

# Now container has 2 network interfaces
```

**Network Architecture:**

```
Host network:
eth0: 192.168.1.100 (host interface)

Docker bridges:
br-frontend: 172.17.0.1 (frontend network)
br-backend: 172.18.0.1 (backend network)

Container:
eth0: 172.17.0.2 (connected to frontend network)
eth1: 172.18.0.3 (connected to backend network)

Network namespace:
├─ eth0 → veth-frontend (connected to br-frontend)
├─ eth1 → veth-backend (connected to br-backend)
└─ lo: 127.0.0.1 (loopback)
```

**Verification:**

```bash
# Inside container
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500

$ ip addr show
1: lo: inet 127.0.0.1/8
2: eth0: inet 172.17.0.2/16 (frontend)
3: eth1: inet 172.18.0.3/16 (backend)

$ route -n
Kernel IP routing table
Destination  Gateway      Genmask      Flags Metric Ref Use Iface
172.17.0.0   0.0.0.0      255.255.0.0  U     0      0   0   eth0
172.18.0.0   0.0.0.0      255.255.0.0  U     0      0   0   eth1
```

**Communication:**

```
Frontend:
Container web (172.17.0.2)
     ├─ Can reach: all containers on frontend network
     │  ├─ db (172.17.0.3)
     │  └─ cache (172.17.0.4)
     └─ Cannot reach: backend network directly

Backend:
Container web (172.18.0.3)
     ├─ Can reach: all containers on backend network
     │  ├─ worker (172.18.0.5)
     │  └─ queue (172.18.0.6)
     └─ Cannot reach: frontend network directly

Multi-network web:
Container web bridges the two networks!
  frontend (172.17.0.2) ← web → backend (172.18.0.3)
  
  From frontend perspective:
  db can reach web (both on frontend)
  
  From backend perspective:
  worker can reach web (both on backend)
  
  web can reach both frontend and backend containers
```

**DNS Resolution:**

```bash
# Inside web container

# Reach frontend container
$ ping db
PING db (172.17.0.3)

# Reach backend container
$ ping worker
PING worker (172.18.0.5)

# How DNS works:
1. Container queries embedded DNS server (127.0.0.11:53)
2. DNS server knows all containers on connected networks
3. Returns IP address of container
4. Container connects directly

# DNS is NOT visible from host
# Each network has its own DNS namespace
```

---

### **Q7: Explain the role of containerd-shim?**

**A:**

**What is shim?**

```
shim (shimmer) is a lightweight process that:
1. Sits between containerd and runc
2. Manages a single container process
3. Handles I/O and signals
4. Reports container status
5. Outlives runc process
```

**Why is shim needed?**

```
Before shim (problems):
├─ runc stays alive for entire container duration
├─ runc per-container overhead significant
├─ Can't upgrade runc without restarting containers
└─ Process tree polluted with runc processes

After shim (solutions):
├─ runc exits immediately after container starts
├─ shim takes over (lightweight process)
├─ Can upgrade runc without affecting running containers
├─ Cleaner process tree
└─ Better resource efficiency
```

**Process Architecture:**

```
Before shim:
PID 1: systemd
└─ PID 100: runc (container 1) — stays alive
   └─ PID 101: container process (sleep)

PID 1: systemd
└─ PID 200: runc (container 2) — stays alive
   └─ PID 201: container process (nginx)

Problems:
├─ Lots of runc processes consuming memory
├─ Runc memory accumulates
└─ Multiple versions of runc can't coexist


After shim:
PID 1: systemd
└─ PID 100: containerd-shim (container 1) — lightweight
   └─ PID 101: container process (sleep)

PID 1: systemd
└─ PID 200: containerd-shim (container 2) — lightweight
   └─ PID 201: container process (nginx)

Benefits:
├─ Shim very lightweight (uses little memory)
├─ runc exited (freed memory)
├─ Can update runc binary
└─ Containers continue running
```

**Shim Responsibilities:**

```
1. Lifecycle Management
   ├─ Created: containerd → runc create → shim start
   ├─ Running: Monitors process
   └─ Exited: Collects exit code

2. I/O Handling
   ├─ Captures stdout/stderr
   ├─ Buffers output
   ├─ Streams to Docker logs
   └─ Cleans up pipes

3. Signal Forwarding
   ├─ SIGTERM → container
   ├─ SIGKILL → container
   ├─ SIGUSR1 → container (custom signals)
   └─ Respects wait time

4. Status Reporting
   ├─ Process running/stopped
   ├─ Exit code
   ├─ Restart count (if restarting)
   └─ Memory usage

5. Checkpoint/Restore (advanced)
   ├─ Pause container state
   ├─ Save to disk
   ├─ Restore later
   └─ (CRIU integration)
```

**Lifecycle:**

```
Step 1: Container Create
├─ containerd: runc create
├─ runc: setup container, fork PID 1, wait
├─ runc: returns control to containerd
└─ runc exits (work done)

Step 2: Container Start
├─ containerd: runc start
├─ runc: resumes PID 1, exits
└─ containerd: launches shim
   └─ shim: monitors PID 1

Step 3: Container Running
├─ shim: reads stdout/stderr
├─ shim: forwards signals to PID 1
├─ shim: reports status to containerd
└─ shim: stays alive

Step 4: Container Stop
├─ Docker: stop command
├─ containerd: send SIGTERM to PID 1
├─ shim: forwards signal
├─ Container: cleanup, exit
├─ shim: collects exit code
├─ shim: notifies containerd
└─ shim exits

Step 5: Container Remove
├─ Delete metadata
├─ Delete shim
├─ Clean up resources
└─ Done
```

**Shim Types:**

```
containerd-shim: Original (default)
├─ Lightweight Go binary
├─ ~2 MB on disk
└─ ~5-10 MB in memory

containerd-shim-runc-v2: Improved
├─ Uses runc syscall interface
├─ Better performance
├─ Built-in cgroup management
└─ Preferred in modern containerd

Shim for other runtimes:
├─ containerd-shim-kata-v2 (for kata runtime)
├─ containerd-shim-crun (for crun runtime)
└─ containerd-shim-gvisor (for gvisor)
```

---

### **Q8: What happens when you exec a command in a running container?**

**A:**

**Command:**

```bash
$ docker exec -it mycontainer /bin/bash

# This spawns a new process inside running container
# Without restarting the container
```

**Process:**

```
Step 1: Docker CLI Parses Command
├─ Command: exec
├─ Container: mycontainer
├─ Command to exec: /bin/bash
├─ Flags: -i (interactive), -t (TTY)
└─ Constructs API request

Step 2: Docker Daemon Receives
├─ Calls: containerd.Exec(container, cmd, opts)
└─ containerd receives request

Step 3: containerd Finds Running Container
├─ Look up container ID
├─ Verify container is running
├─ Get container's shim connection
└─ Ready to exec

Step 4: containerd Calls runc
├─ runc exec <container-id> /bin/bash
├─ runc opens container namespace
├─ Connects to running container's namespaces
└─ Prepares to fork new process

Step 5: runc Prepares New Process
├─ Open container's namespaces
│  ├─ /proc/<container-pid>/ns/pid
│  ├─ /proc/<container-pid>/ns/net
│  ├─ /proc/<container-pid>/ns/ipc
│  ├─ /proc/<container-pid>/ns/uts
│  ├─ /proc/<container-pid>/ns/mnt
│  └─ Obtain file descriptors
│
├─ Use setns() to enter namespaces
│  ├─ setns(pid_ns_fd, CLONE_NEWPID)
│  │  └─ This process now sees container PID namespace
│  ├─ setns(net_ns_fd, CLONE_NEWNET)
│  │  └─ Can see container's network interfaces
│  ├─ setns(ipc_ns_fd, CLONE_NEWIPC)
│  ├─ setns(uts_ns_fd, CLONE_NEWUTS)
│  ├─ setns(mnt_ns_fd, CLONE_NEWNS)
│  └─ (NOT user namespace by default)
│
├─ Set working directory
│  └─ chdir(container_cwd)
│
├─ Setup environment variables
│  └─ execve("/bin/bash", [...], env)
│
└─ Fork new process (child)

Step 6: New Process Execution
├─ Inherits all namespaces
│  ├─ Sees container's processes
│  ├─ Uses container's network
│  ├─ Uses container's filesystem
│  └─ Isolated from host
│
├─ New bash shell runs inside container
│  ├─ PID: something (e.g., 15) INSIDE container
│  ├─ PID: something else (e.g., 45678) on host
│  ├─ Can run commands, interact with container
│  └─ Limited by cgroups (same as container)
│
└─ I/O connected to terminal
   ├─ stdin: connected to user terminal
   ├─ stdout: connected to user terminal
   ├─ stderr: connected to user terminal
   └─ User can type commands

Step 7: User Interacts
├─ User types command (inside container shell)
├─ Bash executes command
├─ Command runs with:
│  ├─ Container's environment
│  ├─ Container's filesystem
│  ├─ Container's processes visible
│  ├─ Container's network interfaces
│  └─ Container's resource limits
└─ Results displayed to user

Step 8: User Exits
├─ User types: exit
├─ Bash process exits
├─ Return code captured
├─ Docker daemon reports exit code
└─ Done

Container still running!
Original process (before exec) continues
Only the bash process exited
```

**Comparison: exec vs run**

```
docker run:
├─ Creates new container
├─ Creates new namespace set
├─ Creates new cgroup
├─ Starts process
└─ Completely isolated new environment

docker exec:
├─ Uses EXISTING container
├─ ENTERS container's namespaces (setns)
├─ Uses container's cgroup
├─ Starts process in container's namespace
└─ New process joins existing namespace
```

**Namespace Inspection:**

```bash
# See process in container
docker exec mycontainer ps aux

# See which namespaces process is in
docker exec mycontainer ls -l /proc/self/ns/
lrwxrwxrwx 1 root root 0 /proc/self/ns/pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 /proc/self/ns/net -> 'net:[4026532508]'
lrwxrwxrwx 1 root root 0 /proc/self/ns/ipc -> 'ipc:[4026531839]'

# Compare with another process in same container
# They have same inode numbers (same namespace)

# Compare with host process
# Different inode numbers (different namespace)
```

---

### **Q9: How does Docker implement resource limits (memory, CPU)?**

**A:**

**Memory Limits:**

```bash
$ docker run -m 512m nginx
# Limit to 512 MB RAM

# What happens:
1. Docker daemon calculates bytes: 512 MB = 536870912 bytes

2. Daemon calls containerd
   CreateContainer(
     ...
     MemoryLimit: 536870912,
     ...
   )

3. containerd generates config.json:
   "linux": {
     "resources": {
       "memory": {
         "limit": 536870912
       }
     }
   }

4. runc creates cgroup:
   mkdir /sys/fs/cgroup/memory/docker/<container>/
   echo 536870912 > /sys/fs/cgroup/memory/docker/<container>/memory.limit_in_bytes

5. runc assigns container process:
   echo <PID> > /sys/fs/cgroup/memory/docker/<container>/cgroup.procs

6. Kernel enforces limit:
   ├─ Each malloc() charged against limit
   ├─ Each page fault checked against limit
   ├─ When limit reached:
   │  ├─ Kernel tries to reclaim cache
   │  ├─ If still over, tries swap
   │  ├─ If still over, selects process to kill
   │  └─ Sends SIGKILL (OOM-killer)
   └─ Container process dies

7. Container stops with exit code 137 (SIGKILL)

8. Docker daemon sees:
   Container exited due to OOM-killer

9. User sees:
   $ docker ps
   # Container not listed (stopped)
   
   $ docker logs mycontainer
   # May show: Killed
```

**CPU Limits:**

```bash
$ docker run --cpus 0.5 nginx
# Limit to 50% of 1 CPU core

# What happens:
1. Docker calculates CPU quota:
   0.5 × 100000 = 50000 microseconds

2. containerd generates config.json:
   "linux": {
     "resources": {
       "cpu": {
         "quota": 50000,
         "period": 100000  # 100 milliseconds
       }
     }
   }

3. runc creates CPU cgroup:
   mkdir /sys/fs/cgroup/cpu/docker/<container>/
   echo 50000 > .../cpu.cfs_quota_us
   echo 100000 > .../cpu.cfs_period_us

4. Kernel scheduler enforces:
   ├─ Every 100 milliseconds (period)
   ├─ Process can run max 50 milliseconds
   ├─ Then kernel throttles (pauses) process
   ├─ Waits until next period
   ├─ Resumes execution
   └─ Repeat

5. Performance:
   ├─ Process can't use more than 0.5 CPU
   ├─ May get less if system idle
   ├─ No killing, just throttling (CPU quota achieved)
   └─ Process runs continuously, just slow
```

**CPU Shares (relative priority):**

```bash
$ docker run --cpu-shares 1024 container1
$ docker run --cpu-shares 2048 container2
# Total shares: 3072

# Behavior:
When both containers competing for CPU:
├─ container1 gets: 1024/3072 = 33% CPU
├─ container2 gets: 2048/3072 = 67% CPU
└─ Total: 100% of 1 core

When only container2 running:
└─ container2 gets: 100% CPU (shares don't limit, just prioritize)

When CPU idle:
└─ Both can use 100% (shares only matter when contending)
```

**CPU Affinity:**

```bash
$ docker run --cpuset-cpus 0-1 nginx
# Use only CPU cores 0 and 1

# What happens:
1. containerd generates config.json:
   "linux": {
     "resources": {
       "cpu": {
         "cpus": "0-1"  # Format: list of CPUs
       }
     }
   }

2. runc creates cpuset cgroup:
   echo "0-1" > /sys/fs/cgroup/cpuset/docker/<container>/cpuset.cpus

3. Kernel scheduler:
   ├─ Container threads pinned to CPU 0 and 1
   ├─ Can't run on CPU 2, 3, etc.
   ├─ Reduces cache misses (thread locality)
   └─ Improves performance

4. Use case:
   ├─ High-performance application
   ├─ NUMA systems (better locality)
   ├─ Isolation (dedicated CPUs per container)
   └─ Deterministic performance
```

**Combined Limits Example:**

```bash
$ docker run \
  -m 512m \
  --cpus 0.5 \
  --cpu-shares 1024 \
  --cpuset-cpus 0-1 \
  --pids-limit 100 \
  --kernel-memory 50m \
  nginx

# Constraints:
├─ RAM: 512 MB max
├─ CPU: 50% of 1 core (capped)
├─ CPU priority: 1024 shares
├─ CPU cores: only 0 and 1
├─ Max processes: 100 (can't fork more)
├─ Kernel memory: 50 MB (for kernel data structures)
└─ All enforced simultaneously
```

**Monitoring:**

```bash
# Check current usage
$ docker stats mycontainer

CONTAINER   CPU %  MEM USAGE / LIMIT  MEM %
mycontainer 12.3%  256 MB / 512 MB     50%

# Detailed cgroup stats
$ cat /sys/fs/cgroup/memory/docker/<id>/memory.stat

cache 12345
rss 234567890
rss_huge 0
mapped_file 0
...

# CPU usage
$ cat /sys/fs/cgroup/cpu/docker/<id>/cpuacct.usage

50000000000  # nanoseconds used

# Check if OOM-killed
$ cat /sys/fs/cgroup/memory/docker/<id>/memory.oom_control

oom_kill_disable 0
under_oom 0
```

---

### **Q10: What is the difference between running as root vs non-root user in a container?**

**A:**

**Running as Root:**

```bash
$ docker run -d ubuntu
# Runs as root (UID 0)

Inside container:
$ id
uid=0(root) gid=0(root) groups=0(root)

$ whoami
root

What root can do:
├─ Install packages (apt-get)
├─ Create files anywhere
├─ Modify system files (/etc)
├─ Change file permissions
├─ Load kernel modules
├─ Open privileged ports (<1024)
└─ Unlimited capabilities

Security implications:
├─ If container compromised, attacker is root
├─ Can modify all container files
├─ Can escalate to host (if vulnerability)
├─ More dangerous!
```

**Running as Non-Root User:**

```bash
$ docker run -d --user 1000 ubuntu
# Runs as UID 1000 (non-root)

Inside container:
$ id
uid=1000 gid=1000 groups=1000

$ whoami
ubuntu (or whatever user)

What non-root can do:
├─ Modify own home directory (~/)
├─ Create files in temp directories (/tmp)
├─ Read world-readable files
├─ Execute scripts user owns
└─ Limited capabilities

What non-root cannot do:
├─ Install packages (need sudo)
├─ Modify system files (/etc)
├─ Listen on privileged ports
├─ Change file permissions beyond scope
├─ Load kernel modules
└─ Much safer!
```

**Dockerfile User Setup:**

```dockerfile
FROM ubuntu:20.04

# Install application
RUN apt-get update && apt-get install -y nginx

# Create non-root user
RUN useradd -m -s /bin/bash appuser

# Switch to non-root
USER appuser

# Run application as non-root
ENTRYPOINT ["nginx", "-g", "daemon off;"]

# Result: nginx runs as appuser, not root
```

**Default User Analysis:**

```dockerfile
FROM ubuntu:20.04
# Default: root

FROM nginx:latest
# Check: USER statement in Dockerfile
# Usually root (needs to bind to port 80)

FROM python:3.11
# Default: root

FROM node:18
# Default: root

Most images default to root!
Need to explicitly switch to non-root
```

**Security Best Practices:**

```dockerfile
# BAD: Runs as root
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y myapp
ENTRYPOINT ["myapp"]

# GOOD: Runs as non-root
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y myapp && \
    useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser
ENTRYPOINT ["myapp"]

# BETTER: Runs as nobody (system user)
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y myapp
USER nobody
ENTRYPOINT ["myapp"]

# BEST: Minimal image + non-root
FROM alpine:latest
RUN adduser -D -S appuser
COPY app /app
USER appuser
ENTRYPOINT ["/app/myapp"]
```

**Capabilities System:**

```bash
# Root user has all capabilities
# Non-root has none by default

# Even root in container can be restricted
$ docker run --cap-drop=ALL nginx

# Capabilities root can lose:
--cap-drop=CAP_NET_ADMIN  # No network admin
--cap-drop=CAP_SYS_ADMIN  # No system admin
--cap-drop=CAP_CHOWN      # Can't change ownership
--cap-drop=ALL            # Drop all

# Capabilities non-root can gain
--cap-add=NET_BIND_SERVICE  # Bind to port 80
--cap-add=CHOWN             # Change ownership

# Typical container doesn't need:
CAP_SYS_ADMIN    # System administration
CAP_NET_ADMIN    # Network administration
CAP_SYS_BOOT     # Reboot
CAP_SYS_MODULE   # Load kernel modules
```

**User Namespace Remapping:**

```bash
# Advanced: Map container root to host non-root

# Setup in /etc/docker/daemon.json
{
  "userns-remap": "default"
}

# Now container root (UID 0):
# - Appears as UID 100000 on host
# - Not actual root!
# - Can't escape to host

# Behavior:
Container: uid=0 (root)
     ↓ (mapped)
Host: uid=100000 (not root!)

# Even if container escaped, only has UID 100000 permissions
# Not dangerous!
```

---
