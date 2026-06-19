# Docker Networks and Volumes: Deep Technical Guide

## Table of Contents
1. [Docker Networks Fundamentals](#docker-networks-fundamentals)
2. [Network Drivers in Depth](#network-drivers-in-depth)
3. [Network Communication](#network-communication)
4. [Docker Volumes Fundamentals](#docker-volumes-fundamentals)
5. [Volume Drivers in Depth](#volume-drivers-in-depth)
6. [Volume Management](#volume-management)
7. [Advanced Topics](#advanced-topics)
8. [Q&A Section](#qa-section)

---

## Docker Networks Fundamentals

### **What is a Docker Network?**

```
A Docker network is a virtualized network connection that allows
containers to communicate with each other and with the host.

It's an abstraction layer on top of Linux networking primitives:
├─ Virtual network interfaces (veth)
├─ Linux bridges
├─ iptables rules
├─ Network namespaces
└─ Linux kernel networking stack
```

### **Network Architecture Overview**

```
┌──────────────────────────────────────────────────────────┐
│                    Host Machine                           │
├──────────────────────────────────────────────────────────┤
│  Physical NIC: eth0 (192.168.1.100)                      │
│       ↓                                                   │
│  Linux Kernel Network Stack                              │
│       ↓                                                   │
│  Docker Network Manager (dockerd)                        │
│       ├─ docker0 bridge (172.17.0.1)                    │
│       ├─ br-frontend (172.18.0.1)                       │
│       ├─ br-backend (172.19.0.1)                        │
│       └─ br-custom (172.20.0.1)                         │
│            ↓                                             │
├────────────────────────────────────────────────────────┤
│  Containers Connected to docker0:                        │
│  ├─ Container A: veth-a (172.17.0.2)                   │
│  └─ Container B: veth-b (172.17.0.3)                   │
│                                                          │
│  Containers Connected to br-frontend:                   │
│  ├─ Container C: veth-c (172.18.0.2)                   │
│  └─ Container D: veth-d (172.18.0.3)                   │
│                                                          │
│  Containers Connected to br-backend:                    │
│  ├─ Container E: veth-e (172.19.0.2)                   │
│  └─ Container F: veth-f (172.19.0.3)                   │
└──────────────────────────────────────────────────────────┘
```

### **Network Lifecycle**

```
1. CREATE: docker network create mynetwork
   ├─ Docker daemon creates network object
   ├─ Allocates IP range (e.g., 172.18.0.0/16)
   ├─ Creates bridge (br-xxx)
   └─ Stores configuration

2. CONNECT: docker network connect mynetwork container
   ├─ Creates veth pair
   ├─ Assigns IP to container
   ├─ Updates iptables
   ├─ Configures DNS
   └─ Container can now communicate

3. COMMUNICATE: Containers on same network exchange packets
   ├─ Via bridge
   ├─ Via routing
   └─ Via DNS resolution

4. DISCONNECT: docker network disconnect mynetwork container
   ├─ Removes veth from bridge
   ├─ Removes IP assignment
   ├─ Updates iptables
   └─ Container loses network access to this network

5. DESTROY: docker network rm mynetwork
   ├─ Removes bridge
   ├─ Cleans up iptables rules
   ├─ Removes network configuration
   └─ Fails if containers still connected
```

---

## Network Drivers in Depth

### **1. Bridge Network Driver (Default)**

#### **Architecture**

```
Host Linux Bridge: docker0
┌──────────────────────────────────┐
│ docker0: 172.17.0.1              │ ← Linux bridge interface
│ ├─ veth12345-br (Container A)    │
│ ├─ veth67890-br (Container B)    │
│ ├─ veth11111-br (Container C)    │
│ └─ veth22222-br (Container D)    │
└──────────────────────────────────┘
     ↓
Host eth0: 192.168.1.100
     ↓
External Network / Internet

Container A:
├─ eth0: veth12345 (paired with veth12345-br)
├─ IP: 172.17.0.2/16
├─ Gateway: 172.17.0.1 (docker0)
└─ Can communicate with other containers on docker0
   Can reach external network via docker0 → eth0

Container B:
├─ eth0: veth67890 (paired with veth67890-br)
├─ IP: 172.17.0.3/16
├─ Gateway: 172.17.0.1 (docker0)
└─ Can communicate with Container A
   Via docker0 bridge
```

#### **Default Bridge Network**

```bash
$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
e82d3f1234ab   bridge    bridge    local
6f1a2b5678cd   host      host      local
3c4d5e9012fg   none      null      local

$ docker network inspect bridge

[
    {
        "Name": "bridge",
        "Id": "e82d3f1234ab...",
        "Created": "2024-01-15T10:00:00.123456789Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
```

#### **Creation and Configuration**

```bash
# View all bridges on host
$ brctl show
bridge name     bridge id           STP enabled    interfaces
docker0         8000.024209e1a2b3   no             veth12345b3
                                                   veth67890c4

# Create container on default bridge
$ docker run -d --name web nginx

# Check container IP
$ docker inspect web | grep -A 10 "IPAddress"
"IPAddress": "172.17.0.2"
"IPPrefixLen": 16
"Gateway": "172.17.0.1"

# Container's network configuration
$ docker exec web ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500

$ docker exec web ip addr show
1: lo: inet 127.0.0.1/8
2: eth0: inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0

$ docker exec web ip route show
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2

# Host view
$ ip link show docker0
5: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether 02:42:09:e1:a2:b3 brd ff:ff:ff:ff:ff:ff

$ ip addr show docker0
5: docker0: inet 172.17.0.1/16 scope global docker0

$ brctl show docker0
bridge name     bridge id           STP enabled    interfaces
docker0         8000.024209e1a2b3   no             veth12345b3
                                                   veth67890c4
```

#### **Communication Flow**

```
Container A → Container B (same bridge):

1. Container A wants to send to 172.17.0.3

2. Container A routing table:
   Destination  Gateway  Interface
   172.17.0.0   0.0.0.0  eth0
   
   Matches: send directly to eth0 (no gateway needed)

3. Container A sends ARP: Who is 172.17.0.3?
   ARP broadcasts to all containers on docker0

4. Container B responds: I am 172.17.0.3 at MAC xx:xx:xx:xx:xx:xx

5. Container A sends packet:
   Src: 172.17.0.2 (Container A)
   Dst: 172.17.0.3 (Container B)
   Via eth0 (veth pair)

6. Kernel transfers packet through veth pair
   Container A side: veth12345
   Bridge side: veth12345-br
   
7. Bridge (docker0) forwards packet to veth67890-br
   (checks MAC address table)

8. Kernel transfers packet to Container B
   Container B side: veth67890
   Packet delivered to eth0

9. Container B receives packet
   Delivers to listening process
```

#### **Port Mapping with iptables**

```bash
$ docker run -d -p 8080:80 nginx

# What Docker creates:

# 1. Bridge port mapping (userland-proxy)
#    Listens on 0.0.0.0:8080
#    Forwards to container 172.17.0.2:80

# 2. iptables rules (kernel-level NAT)

# View NAT rules
$ iptables -t nat -L DOCKER

Chain DOCKER (2 references)
target     prot opt source      destination
DNAT       tcp  --  anywhere    anywhere    tcp dpt:8080 to:172.17.0.2:80
DNAT       tcp  --  anywhere    anywhere    tcp dpt:8081 to:172.17.0.3:80

# Connection flow:
Client request: 192.168.1.100:8080

1. Host receives on port 8080
2. iptables PREROUTING matches:
   -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80

3. Destination NAT applied:
   Original dest: 192.168.1.100:8080
   New dest: 172.17.0.2:80

4. Kernel routes to docker0 bridge
5. Bridge forwards to container veth pair
6. Container receives on eth0:80
7. nginx processes request

8. Response goes back:
   Source: 172.17.0.2:80
   Destination: client IP
   
9. Reverse NAT applied:
   Source: 192.168.1.100:8080 (masquerade)
   
10. Client receives response from 192.168.1.100:8080 ✓
```

#### **Bridge Network Options**

```bash
# Custom bridge network with options
$ docker network create \
    --driver bridge \
    --subnet 172.25.0.0/16 \
    --ip-range 172.25.5.0/24 \
    --gateway 172.25.0.1 \
    --opt com.docker.network.bridge.name=br-custom \
    --opt com.docker.network.bridge.enable_icc=true \
    --opt com.docker.network.bridge.enable_ip_masquerade=true \
    --opt "com.docker.network.driver.mtu=1500" \
    mynetwork

# Options explained:
--subnet 172.25.0.0/16
  Full address space for network

--ip-range 172.25.5.0/24
  Where IPs are assigned (subset of subnet)
  Useful for reserving IPs

--gateway 172.25.0.1
  Default gateway for containers

--opt com.docker.network.bridge.name=br-custom
  Linux bridge name (default: br-xxx)

--opt com.docker.network.bridge.enable_icc=true
  inter-container communication enabled

--opt com.docker.network.bridge.enable_ip_masquerade=true
  Outgoing traffic gets NATed

--opt "com.docker.network.driver.mtu=1500"
  Maximum transmission unit (packet size)
```

#### **Bridge vs Default Bridge**

```
Default Bridge (docker0):
├─ Automatic (created at Docker startup)
├─ Docker DNS NOT available
├─ Container must use IP to communicate
├─ Cannot use container name resolution
└─ Older style, not recommended

Custom Bridge:
├─ Manually created
├─ Embedded Docker DNS available
├─ Container can use container name
├─ Automatic service discovery
├─ Better isolation
├─ Better suited for production
└─ Recommended approach

Example - Default Bridge (no DNS):
$ docker run -d --name web1 nginx
$ docker run -d --name web2 nginx
$ docker exec web2 ping web1
PING web1 (172.17.0.2) 56(84) bytes of data
# Must use IP, not name!

Example - Custom Bridge (with DNS):
$ docker network create mynet
$ docker run -d --name web1 --network mynet nginx
$ docker run -d --name web2 --network mynet nginx
$ docker exec web2 ping web1
PING web1 (172.18.0.2) 56(84) bytes of data
# Works! Automatic DNS resolution
```

### **2. Host Network Driver**

#### **Concept**

```
Host network = No isolation

Container shares host's network namespace
├─ No network isolation
├─ Direct access to host network interfaces
├─ No veth pair creation
├─ No bridge
├─ Container sees all host network interfaces
├─ Container ports are directly host ports
└─ Maximum performance
```

#### **Architecture**

```
Without Host Network (Bridge):
┌──────────────────┐
│ Container        │
├──────────────────┤
│ Network NS       │
│ ├─ eth0          │
│ ├─ IP: 172.17.x.x
│ └─ Port: 8080
└────────┬─────────┘
         │ (veth pair, NAT)
         ↓
Host Network:
├─ eth0: 192.168.1.100
├─ Port: 8080 (mapped to container)
└─ → Internet

With Host Network:
┌──────────────────┐
│ Container        │
├──────────────────┤
│ Host Network NS  │ ← SHARED!
│ ├─ eth0          │
│ ├─ IP: 192.168.1.100
│ └─ Port: 8080 (direct)
└────────┬─────────┘
         │ (same namespace)
         ↓
Host Network:
├─ eth0: 192.168.1.100 (same!)
├─ Port: 8080 (same container process)
└─ → Internet (direct)
```

#### **Usage**

```bash
# Create container with host network
$ docker run -d --network host nginx

# Inside container
$ ip link show
Same as host:
├─ eth0 (physical interface)
├─ docker0 (bridge)
└─ lo (loopback)

$ ip addr show eth0
inet 192.168.1.100/24
(Same as host!)

$ netstat -tulpn
tcp     0   0 0.0.0.0:80      0.0.0.0:*  LISTEN
tcp     0   0 0.0.0.0:443     0.0.0.0:*  LISTEN
# Listens on host IPs!

# Host side
$ netstat -tulpn | grep ":80"
tcp  0  0 0.0.0.0:80  0.0.0.0:*  LISTEN
# Same process! No NAT involved
```

#### **Characteristics**

```
Advantages:
├─ Maximum performance (no NAT overhead)
├─ Direct access to host network
├─ No port mapping needed
├─ Direct bandwidth utilization
└─ Useful for network-intensive apps

Disadvantages:
├─ No network isolation
├─ Port conflicts (can't use same port twice)
├─ Security risk (direct host access)
├─ Can't have multiple containers on same port
├─ Not portable (tied to host network)
└─ Problematic in development/testing

Use Cases:
├─ Network measurement tools
├─ High-performance networking applications
├─ Monitoring agents
├─ Load balancers (nginx, haproxy)
└─ NOT suitable for normal applications

Restrictions:
├─ -p port mapping doesn't work (warning ignored)
├─ Container hostname = host hostname
└─ Can't use container DNS resolution
```

### **3. None Network Driver**

#### **Concept**

```
None network = No networking

Container has NO network connectivity
├─ Only loopback interface (127.0.0.1)
├─ Can't reach other containers
├─ Can't reach external network
├─ Can't reach host
└─ Complete isolation
```

#### **Architecture**

```
┌──────────────────────┐
│ Container            │
├──────────────────────┤
│ Isolated Network NS  │
│ ├─ lo: 127.0.0.1    │
│ └─ (no eth0!)       │
└──────────────────────┘

No bridges, no veth pairs, no connectivity
```

#### **Usage**

```bash
# Create container with no network
$ docker run -d --network none ubuntu sleep 1000

# Inside container
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP>
# ONLY loopback!

$ ip addr show
1: lo: inet 127.0.0.1/8
# ONLY loopback IP!

$ ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data
(hanging... no response)
# Can't reach external network

$ ping localhost
PING localhost (127.0.0.1) 56(84) bytes of data
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.123 ms
# Can reach self only
```

#### **Use Cases**

```
batch processing:
├─ No network access needed
├─ Process data locally
├─ Write results to volume
└─ Example: image processing, data transformation

testing network isolation:
├─ Test application behavior without network
├─ Test data persistence (volumes work)
├─ Verify offline functionality
└─ Security testing

sandboxed applications:
├─ Run untrusted code
├─ No network escape possible
├─ Can only access local files (mounted volumes)
└─ Maximum isolation

offline computation:
├─ Machine learning model training
├─ Data processing
├─ File format conversion
└─ No internet needed
```

### **4. Overlay Network Driver**

#### **Concept**

```
Overlay network = Multi-host networking

For Docker Swarm (orchestration mode)
├─ Connects containers across multiple hosts
├─ Uses VXLAN tunneling
├─ Encrypted communication
├─ Service discovery
└─ Load balancing

NOT for single-host setup (use bridge for that)
```

#### **Architecture (Swarm Mode)**

```
Host 1: 192.168.1.100
├─ Manager: 10.0.9.1 (overlay network)
├─ Worker1: 10.0.9.2 (overlay network)
└─ vxlan0 tunnel interface

Host 2: 192.168.1.101
├─ Worker2: 10.0.9.3 (overlay network)
├─ Worker3: 10.0.9.4 (overlay network)
└─ vxlan0 tunnel interface

VXLAN Tunnel (encrypted):
Host 1 vxlan0 ←→ (UDP 4789) ←→ Host 2 vxlan0

Container A → Container B:
Container A (10.0.9.2)
  └─ Packet to 10.0.9.3
  └─ Local bridge decides: remote host
  └─ VXLAN encapsulation
  └─ UDP packet to Host 2:4789
  └─ Host 2 decapsulates
  └─ Delivers to Container B (10.0.9.3)
```

#### **Usage**

```bash
# Only in Swarm mode
$ docker swarm init
Swarm initialized

# Create overlay network
$ docker network create --driver overlay mynetwork

# Deploy service
$ docker service create --network mynetwork --name web nginx

# Service replicas on different hosts
# All communicate via overlay network
# Transparent multi-host networking
```

### **5. Macvlan Network Driver**

#### **Concept**

```
Macvlan = Direct MAC address assignment

Each container gets own MAC address
├─ Appears as physical device on network
├─ Gets IP from external network (not Docker subnet)
├─ Direct communication without bridge
├─ High performance
└─ Can be accessed from outside Docker
```

#### **Architecture**

```
Physical Network: 192.168.1.0/24
├─ Gateway: 192.168.1.1
├─ Host: 192.168.1.100
├─ Other servers: 192.168.1.101-199
└─ Available IPs: 192.168.1.200-254

Macvlan Network:
├─ Container A: 192.168.1.200 (separate MAC)
├─ Container B: 192.168.1.201 (separate MAC)
└─ Container C: 192.168.1.202 (separate MAC)

Each container:
├─ Real IP (from network)
├─ Real MAC address
├─ Directly on network
└─ Accessible from outside Docker
```

#### **Usage**

```bash
# Create macvlan network
$ docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  mynet

# Container gets real IP
$ docker run -d --network mynet ubuntu

# Inside container
$ ip addr show
inet 192.168.1.200/24 dev eth0
# Real IP on physical network!

# From outside Docker
$ ping 192.168.1.200
PING 192.168.1.200
# Works! Reachable from network
```

#### **Characteristics**

```
Advantages:
├─ Appears as physical device
├─ Real IP from network
├─ High performance
├─ Suitable for legacy network integration
└─ Can be managed by network admins

Disadvantages:
├─ Requires parent interface
├─ MAC address management complex
├─ Network switch might have MAC limit
├─ All containers on same network
├─ No service discovery
└─ Not suitable for most Docker use cases
```

---

## Network Communication

### **DNS Resolution in Docker Networks**

#### **Default Bridge (No DNS)**

```bash
# Create two containers on default bridge
$ docker run -d --name web1 nginx
$ docker run -d --name web2 nginx

# Try to communicate
$ docker exec web2 ping web1
ping: web1: Name or address not known
# DNS resolution fails!

# Must use IP
$ docker exec web2 ping 172.17.0.2
PING 172.17.0.2 (172.17.0.2) 56(84) bytes of data
# Works with IP
```

#### **Custom Bridge (With DNS)**

```bash
# Create custom bridge network
$ docker network create mynet

# Create containers on custom network
$ docker run -d --name web1 --network mynet nginx
$ docker run -d --name web2 --network mynet nginx

# DNS resolution works
$ docker exec web2 ping web1
PING web1 (172.18.0.2) 56(84) bytes of data
# Works! DNS automatic

# How it works:
$ docker exec web2 cat /etc/resolv.conf
nameserver 127.0.0.11
# Embedded DNS server
```

#### **Embedded DNS Server**

```
Docker embedded DNS:
├─ Listens on 127.0.0.11:53
├─ Only inside containers (not accessible from host)
├─ Automatically configured
├─ Knows all containers on same network
└─ Automatic service discovery

Container DNS Query:
1. Container app: getaddrinfo("web1", ...)
2. libc resolver library
3. Queries 127.0.0.11:53 (Docker DNS)
4. Docker DNS checks:
   ├─ Container on same network?
   ├─ Container name = "web1"?
   ├─ Return IP: 172.18.0.2
   └─ Response to container
5. Application receives IP
6. Opens connection to 172.18.0.2
```

#### **Round-robin DNS (Load Balancing)**

```bash
# Create network
$ docker network create mynet

# Create multiple containers with same name (impossible!)
# Instead: use Docker services (Swarm mode)

# In Swarm:
$ docker service create --name web --network mynet nginx:1
$ docker service update --mode replicated --replicas 3 web

# Now 3 replicas of "web"
# Each has different container ID
# Same service name "web"

# DNS resolution with round-robin:
$ dig web
web.   600  IN  A  10.0.9.2
web.   600  IN  A  10.0.9.3
web.   600  IN  A  10.0.9.4

# Each lookup returns different IP (round-robin)
# Load distributed across replicas
```

### **Port Exposure and Publishing**

#### **EXPOSE vs -p**

```dockerfile
# EXPOSE (documentation only)
FROM nginx:latest
EXPOSE 80 443
# Tells readers: "This image listens on 80 and 443"
# Does NOT actually expose ports!
```

```bash
# EXPOSE in container
$ docker run nginx
# Ports NOT published
# Container accessible only from other containers on same bridge

# To reach from outside:
$ curl 172.17.0.2:80  # Must use container IP
# Can't reach from host port 80!
```

```bash
# -p (actually publishes)
$ docker run -d -p 8080:80 nginx
# Now EXPOSED!
# Host port 8080 mapped to container port 80

# Accessible from:
$ curl localhost:8080  ✓ Works
$ curl 127.0.0.1:8080  ✓ Works
$ curl 192.168.1.100:8080  ✓ Works (host IP)
$ curl 172.17.0.2:80  ✓ Works (container IP, but slower)
```

#### **Port Publishing Options**

```bash
# Specific interface
$ docker run -d -p 127.0.0.1:8080:80 nginx
# Only accessible from localhost
$ curl localhost:8080  ✓
$ curl 192.168.1.100:8080  ✗ Fails

# Any interface (default)
$ docker run -d -p 8080:80 nginx
# Same as: -p 0.0.0.0:8080:80
# Accessible from anywhere
$ curl 0.0.0.0:8080  ✓
$ curl localhost:8080  ✓
$ curl 192.168.1.100:8080  ✓
$ curl external-ip:8080  ✓

# Multiple ports
$ docker run -d -p 80:80 -p 443:443 nginx
# Expose both HTTP and HTTPS

# Port ranges
$ docker run -d -p 8000-8010:7000-7010 nginx
# Maps 8000→7000, 8001→7001, ..., 8010→7010

# Random host port
$ docker run -d -p 80 nginx
# Host port auto-assigned (random)
$ docker port <container>
80/tcp → 0.0.0.0:32768
```

#### **How Port Publishing Works**

```
iptables DNAT (Destination NAT):

Host receives packet: 0.0.0.0:8080
    ↓
Kernel routing:
    -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80

Packet transformed:
Original: 0.0.0.0:8080
New: 172.17.0.2:80
    ↓
Kernel routes to docker0 bridge
    ↓
Bridge sends to container via veth pair
    ↓
Container receives on eth0:80
    ↓
Application listens on 80 → handles request

Response packet:
Source: 172.17.0.2:80
Destination: client IP
    ↓
iptables reverse NAT (SNAT):
    -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    Source NATted: 172.17.0.2 → 0.0.0.0

Client receives response from 0.0.0.0:8080 ✓
```

---

## Docker Volumes Fundamentals

### **What is a Docker Volume?**

```
A Docker volume is a mechanism for persisting data
outside of container filesystem.

Types of storage:
├─ Ephemeral (container layer) → Lost on delete
├─ Volumes → Persisted, managed by Docker
├─ Bind mounts → Host directory
├─ tmpfs mounts → In-memory
└─ npipe (Windows)

Volume characteristics:
├─ Decoupled from container lifecycle
├─ Can be shared between containers
├─ Can be backed up/migrated
├─ Can have drivers (local, nfs, etc.)
└─ Can be encrypted
```

### **Volume Lifecycle**

```
CREATE: docker volume create myvolume
    ├─ Creates named volume
    ├─ Allocates storage
    ├─ Stores metadata
    └─ Ready to mount

MOUNT: docker run -v myvolume:/app/data container
    ├─ Connects volume to container path
    ├─ Mounts to /app/data inside container
    └─ Data accessible to container

USE: Container writes to /app/data
    ├─ Data stored in volume
    ├─ Survives container restart
    └─ Survives container deletion

UNMOUNT: Container stops/deleted
    ├─ Volume still exists
    ├─ Data persists
    └─ Can be remounted to another container

DELETE: docker volume rm myvolume
    ├─ Only possible if no containers using it
    ├─ Deletes volume data
    ├─ Freed storage
    └─ Cannot undo!
```

### **Volume Types**

```
1. Named Volume
   ├─ Has a name (docker volume create mydata)
   ├─ Managed by Docker
   ├─ Stored in /var/lib/docker/volumes/
   ├─ Portable between containers
   └─ Recommended for production

2. Anonymous Volume
   ├─ No explicit name
   ├─ Auto-generated ID
   ├─ Deleted when container removed (--rm)
   ├─ Hard to reuse
   └─ Good for temporary data

3. Bind Mount
   ├─ Host directory
   ├─ Full host path specified
   ├─ Direct access to host files
   ├─ Good for development
   └─ Platform-dependent paths

4. tmpfs Mount
   ├─ In-memory storage
   ├─ Not persisted
   ├─ Very fast
   ├─ Lost on container exit
   └─ Good for sensitive data
```

---

## Volume Drivers in Depth

### **1. Local Volume Driver (Default)**

#### **Concept**

```
Local volume = Stored on the same machine

Storage location: /var/lib/docker/volumes/
├─ Docker-managed filesystem
├─ Persists across container lifecycle
├─ Works on single host only
└─ Limited by host storage
```

#### **Architecture**

```
Host filesystem:
/var/lib/docker/
├─ volumes/
│  ├─ mydata/
│  │  └─ _data/          ← Actual volume data
│  │     ├─ file1.txt
│  │     ├─ file2.txt
│  │     └─ subdir/
│  ├─ dbdata/
│  │  └─ _data/
│  │     ├─ data.db
│  │     └─ index.db
│  └─ logdata/
│     └─ _data/
│        └─ app.log
│
├─ containers/
├─ images/
└─ ...

Container mounts:
Container A: /app/data → /var/lib/docker/volumes/mydata/_data/
Container B: /data → /var/lib/docker/volumes/dbdata/_data/
Container C: /logs → /var/lib/docker/volumes/logdata/_data/
```

#### **Usage**

```bash
# Create named volume
$ docker volume create mydata

# Inspect volume
$ docker volume inspect mydata

[
    {
        "Name": "mydata",
        "Driver": "local",
        "Mountpoint": "/var/lib/docker/volumes/mydata/_data",
        "Labels": {},
        "Scope": "local"
    }
]

# Mount volume to container
$ docker run -d -v mydata:/app/data ubuntu sleep 1000

# Verify mount inside container
$ docker exec <container> df /app/data

Filesystem     1K-blocks Used Available Use% Mounted on
/dev/sda1      41151360 12345 38806015   1% /app/data

# View files from host
$ ls /var/lib/docker/volumes/mydata/_data/
file1.txt  file2.txt  directory/

# Container writes data
$ docker exec <container> echo "hello" > /app/data/test.txt

# View from host
$ cat /var/lib/docker/volumes/mydata/_data/test.txt
hello
```

#### **Volume Options**

```bash
# Type of mount
-v mydata:/app/data          # Read-write (default)
-v mydata:/app/data:ro       # Read-only
-v mydata:/app/data:rw       # Explicit read-write

# Mount propagation options
-v mydata:/app/data:rprivate  # Default, private
-v mydata:/app/data:rslave    # Slave mount
-v mydata:/app/data:rshared   # Shared mount
-v mydata:/app/data:nosuid    # No setuid
-v mydata:/app/data:noexec    # No execute
-v mydata:/app/data:nodev     # No device access

# Example: read-only volume for secrets
docker run -v secrets:/etc/secrets:ro myapp
# App can read secrets, but can't modify
```

#### **Volume Metadata**

```bash
# Docker stores volume metadata
$ ls -la /var/lib/docker/volumes/mydata/

total 12
drwxr-xr-x 3 root root 4096 Jan 15 10:00 .
drwxr-xr-x 5 root root 4096 Jan 15 10:00 ..
-rw-r--r-- 1 root root 1234 Jan 15 10:00 metadata.db
drwx-----x 2 root root 4096 Jan 15 10:00 _data

# metadata.db contains:
# - Volume name
# - Creation date
# - Labels
# - Driver options
# - Mount count
# - Container references
```

### **2. NFS Volume Driver**

#### **Concept**

```
NFS volume = Remote network storage

Useful for:
├─ Multi-host deployments
├─ Shared storage across containers
├─ Persistent storage in orchestration
├─ Backup and recovery
└─ High availability
```

#### **Architecture**

```
NFS Server: 192.168.1.50
├─ /exports/docker-data/
│  ├─ project1/
│  ├─ project2/
│  └─ project3/
└─ Exported to Docker hosts

Docker Host 1: 192.168.1.100
├─ NFS mount: /mnt/nfs (from NFS server)
├─ Container A: /data → NFS:/exports/project1/
├─ Container B: /data → NFS:/exports/project2/
└─ Local volume: /var/lib/docker/volumes/

Docker Host 2: 192.168.1.101
├─ NFS mount: /mnt/nfs (same NFS server)
├─ Container C: /data → NFS:/exports/project1/ (SHARED!)
├─ Container D: /data → NFS:/exports/project3/
└─ Local volume: /var/lib/docker/volumes/

Shared Volume:
NFS:/exports/project1/ ←← Mounted by Container A and C
  ├─ Container A: Host 1
  └─ Container C: Host 2 (can access same data!)
```

#### **Setup**

```bash
# Install NFS driver
docker plugin install --grant-all-permissions \
  vieux/nfs4

# Or use native NFS (Linux)
# NFS already supported in kernel

# Create NFS volume
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.50,vers=4,soft,timeo=180,bg,tcp \
  --opt device=:/exports/data \
  nfs-data

# Mount to container
docker run -d -v nfs-data:/app/data myapp

# Inside container: /app/data → NFS server:/exports/data
# Automatically mounted and accessible
```

#### **Characteristics**

```
Advantages:
├─ Shared storage across hosts
├─ High availability
├─ Backup on server side
├─ Scalable to multiple hosts
├─ Data survives host failure
└─ Suitable for stateful applications

Disadvantages:
├─ Network latency
├─ Dependency on NFS server
├─ Server becomes bottleneck
├─ Network traffic overhead
├─ Configuration complexity
└─ Performance not as good as local
```

### **3. Other Volume Drivers**

```
Docker Volume Plugin Ecosystem:

1. netshare (SMB/CIFS) - Windows file sharing
   ├─ Mount Windows SMB shares
   └─ Useful for Windows-based infrastructure

2. convoy - Block storage
   ├─ Attach/detach volumes
   ├─ Snapshots support
   └─ Cloud storage integration

3. REX-Ray - Enterprise storage
   ├─ AWS EBS, Google Persistent Disk, etc.
   ├─ Snapshots and backups
   ├─ High availability
   └─ Production-ready

4. Portworx - Distributed storage
   ├─ Data replication
   ├─ Automated failover
   ├─ Encryption
   └─ Kubernetes integration

5. StorageOS - Cloud-native storage
   ├─ Containerized storage
   ├─ Replication
   ├─ Snapshots
   └─ High availability

Choosing driver:
├─ Single host? Use local
├─ Multiple hosts? Use NFS or cloud storage
├─ High availability? Use REX-Ray or Portworx
├─ Cloud? Use cloud-native driver (EBS, GCP, etc.)
└─ Kubernetes? Use cloud-native + Kubernetes driver
```

---

## Volume Management

### **Volume Operations**

```bash
# List volumes
$ docker volume ls
DRIVER    VOLUME NAME
local     mydata
local     dbdata
local     logdata

# Inspect volume
$ docker volume inspect mydata
[
    {
        "Name": "mydata",
        "Driver": "local",
        "Mountpoint": "/var/lib/docker/volumes/mydata/_data",
        "Labels": {},
        "Scope": "local"
    }
]

# Create volume with options
$ docker volume create \
    --label env=production \
    --label app=web \
    prod-data

# Remove volume
$ docker volume rm mydata
# Only works if not in use

# Remove all unused volumes
$ docker volume prune
WARNING! This will remove all local volumes not used by at least one container.
Are you sure you want to continue? [y/N] y
Deleted Volumes:
unused1
unused2

Total reclaimed space: 1.2GB

# Check volume usage
$ du -sh /var/lib/docker/volumes/*/
1.5G /var/lib/docker/volumes/db_data/
500M /var/lib/docker/volumes/logs/
2.0G /var/lib/docker/volumes/backups/
```

### **Data Sharing Between Containers**

#### **Multiple Containers Same Volume**

```bash
# Create volume
$ docker volume create shared-data

# Container 1: writes data
$ docker run -d --name writer \
    -v shared-data:/data \
    ubuntu bash -c "echo 'hello' > /data/message.txt; sleep 1000"

# Container 2: reads data
$ docker run -d --name reader \
    -v shared-data:/data \
    ubuntu bash -c "cat /data/message.txt; sleep 1000"

# Verify
$ docker exec reader cat /data/message.txt
hello

# Container 3: also reads
$ docker run -d --name viewer \
    -v shared-data:/data \
    ubuntu bash -c "cat /data/message.txt"

# All three containers access same volume
# Data shared between them
# Changes visible to all
```

#### **Volume from Container**

```bash
# Container 1: volume provider
$ docker run -d --name data-provider \
    -v mydata:/data \
    ubuntu sleep 1000

# Container 2: uses volumes from Container 1
$ docker run -d --name app \
    --volumes-from data-provider \
    myapp
# Now app has access to /data (same volume as data-provider)

# Container 3: also uses same volumes
$ docker run -d --name backup \
    --volumes-from data-provider \
    backup-tool
# All three share same volume

# Verify all can see data
$ docker exec data-provider sh -c "echo 'test' > /data/shared.txt"
$ docker exec app cat /data/shared.txt
test
$ docker exec backup cat /data/shared.txt
test
```

#### **Data Persistence Pattern**

```bash
# Run database with volume
$ docker run -d --name db \
    -v db_data:/var/lib/postgresql \
    postgres

# Application connects to database
$ docker run -d --name app \
    --link db:database \
    myapp

# Database data persisted in volume
# Container can be deleted and recreated
$ docker rm db

# New database container with same volume
$ docker run -d --name db \
    -v db_data:/var/lib/postgresql \
    postgres
# Data recovered! All tables intact
```

### **Backup and Restore**

#### **Backup Volume**

```bash
# Create backup container that mounts volume
$ docker run --rm \
    --volumes-from db \
    -v $(pwd):/backup \
    ubuntu tar czf /backup/db-backup.tar.gz \
    -C /var/lib/postgresql .

# What happens:
# 1. Create temporary container
# 2. Mount db's volumes
# 3. Mount current directory as /backup
# 4. tar: compress /var/lib/postgresql → /backup/db-backup.tar.gz
# 5. Remove temporary container
# 6. Backup file saved on host

$ ls -lh db-backup.tar.gz
-rw-r--r-- 1 root root 1.2G Jan 15 10:30 db-backup.tar.gz
```

#### **Restore Volume**

```bash
# Create new volume
$ docker volume create db_data_restored

# Restore from backup
$ docker run --rm \
    -v db_data_restored:/var/lib/postgresql \
    -v $(pwd):/backup \
    ubuntu tar xzf /backup/db-backup.tar.gz \
    -C /var/lib/postgresql

# What happens:
# 1. Create temporary container
# 2. Mount new volume
# 3. Mount backup file
# 4. tar: extract /backup/db-backup.tar.gz → /var/lib/postgresql
# 5. Remove temporary container
# 6. Data restored in new volume

# Start database with restored volume
$ docker run -d --name db \
    -v db_data_restored:/var/lib/postgresql \
    postgres
# Database restored with all data!
```

#### **Migrate Volume Between Hosts**

```bash
# Host 1: Backup volume
$ docker run --rm \
    -v mydata:/source \
    -v /tmp:/backup \
    ubuntu tar czf /backup/mydata.tar.gz -C /source .

# Copy to Host 2
$ scp /tmp/mydata.tar.gz user@host2:/tmp/

# Host 2: Restore volume
$ docker volume create mydata

$ docker run --rm \
    -v mydata:/target \
    -v /tmp:/backup \
    ubuntu tar xzf /backup/mydata.tar.gz -C /target

# Volume now available on Host 2
# Start container with restored volume
$ docker run -d -v mydata:/data ubuntu
```

---

## Advanced Topics

### **1. Network Security**

#### **Default Isolation**

```
Bridge network isolation:

Container A (172.17.0.2):
├─ Can reach Container B (172.17.0.3) on same network
├─ Can reach host (172.17.0.1)
├─ Can reach external networks (with NAT)
└─ CANNOT reach containers on other networks

Container B (172.17.0.3):
├─ Can reach Container A
├─ Can reach host
├─ Can reach external networks (with NAT)
└─ CANNOT reach containers on different network

Host:
├─ Can reach all containers on docker0
├─ Can reach all containers via port mappings
├─ Can reach containers on other bridges
└─ CAN reach all containers directly

Security implications:
├─ Containers on same network trust each other
├─ Different networks are isolated
├─ Host has access to all containers
├─ Use different networks for isolation
└─ Network segregation by function
```

#### **Inter-Container Communication Control**

```bash
# Disable inter-container communication
$ docker run -d \
    --network mynet \
    --icc=false \
    container1

$ docker run -d \
    --network mynet \
    --icc=false \
    container2

# Now container1 cannot reach container2
# Even on same network!
# Better isolation

# But service discovery still works:
$ docker exec container1 ping container2
# DNS resolves, but network unreachable
# (application error, not network error)
```

#### **Network Policy**

```bash
# Using firewall rules (iptables)
# Docker doesn't have native network policies

# But can implement with iptables:
iptables -A DOCKER-USER -i docker0 \
    -p tcp --dport 3306 -j DROP
# Blocks port 3306 on docker0

iptables -A DOCKER-USER -i docker0 \
    -p tcp --dport 3306 \
    -s 172.17.0.2 \
    -j ACCEPT
# Allow only from specific container

# For orchestration (Kubernetes, Swarm):
# Use native network policies
```

### **2. Storage and Performance**

#### **Volume Performance**

```
Local volume:
├─ Direct filesystem access
├─ Fastest option
├─ No network overhead
└─ Suitable for high I/O applications

Bind mount (host directory):
├─ Direct filesystem access
├─ Same speed as local volume
├─ Useful for development
└─ Good performance

NFS volume:
├─ Network latency overhead
├─ Slower than local
├─ Still usable for most apps
├─ Trade performance for sharing

tmpfs mount:
├─ In-memory access
├─ Fastest I/O
├─ No disk access
├─ Limited by memory
└─ Good for caches, temp files
```

#### **Volume Capacity Planning**

```bash
# Check volume usage
$ du -sh /var/lib/docker/volumes/db_data/_data/

# Monitor volume growth
$ watch -n 1 "du -sh /var/lib/docker/volumes/db_data/_data/"

# Calculate needed space
$ df -h /var/lib/docker/volumes/

# Usage example:
Database volume: 50GB
Log volume: 10GB
Cache volume: 5GB
User data: 100GB
Total: 165GB
Available: 500GB
Headroom: 335GB ✓

# Warning signs:
├─ Volume > 80% capacity
├─ Volume growing > 10%/day
├─ Remaining space < 20GB
└─ Action: add storage or cleanup
```

### **3. Backup Strategy**

#### **Volume Backup Best Practices**

```
1. Regular Backups
   ├─ Automate backup schedule
   ├─ Daily backups for important data
   ├─ Weekly full backups
   └─ Monthly archives

2. Off-site Storage
   ├─ Don't store backup on same host
   ├─ Use external storage (NFS, S3, etc.)
   ├─ Replicate to cloud
   └─ Geographic distribution

3. Backup Verification
   ├─ Test restore regularly
   ├─ Verify backup integrity
   ├─ Document restore procedure
   └─ Practice disaster recovery

4. Encryption
   ├─ Encrypt backups in transit
   ├─ Encrypt backups at rest
   ├─ Manage encryption keys securely
   └─ Backup key separately

5. Retention Policy
   ├─ Define retention period
   ├─ Delete old backups
   ├─ Comply with regulations
   └─ Document policy
```

#### **Backup Script Example**

```bash
#!/bin/bash

# Backup script for Docker volumes

BACKUP_DIR="/backup/docker-volumes"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/var/log/docker-backup.log"

# Function: backup volume
backup_volume() {
    local volume=$1
    local backup_file="$BACKUP_DIR/${volume}-${TIMESTAMP}.tar.gz"
    
    echo "[$(date)] Backing up $volume..." | tee -a $LOG_FILE
    
    docker run --rm \
        -v "$volume:/source" \
        -v "$BACKUP_DIR:/backup" \
        ubuntu tar czf "/backup/$(basename $backup_file)" \
        -C /source . 2>> $LOG_FILE
    
    if [ $? -eq 0 ]; then
        echo "[$(date)] ✓ $volume backed up successfully" | tee -a $LOG_FILE
        # Upload to cloud
        aws s3 cp "$backup_file" "s3://backups/docker/${volume}/"
    else
        echo "[$(date)] ✗ $volume backup failed" | tee -a $LOG_FILE
        # Send alert
        mail -s "Docker backup failed: $volume" admin@example.com < $LOG_FILE
    fi
}

# Backup all volumes
docker volume ls -q | while read volume; do
    backup_volume "$volume"
done

echo "[$(date)] Backup complete" | tee -a $LOG_FILE
```

---

## Q&A Section

### **Q1: What is the difference between bridge and host network?**

**A:**

| Aspect | Bridge Network | Host Network |
|--------|---|---|
| **Isolation** | Isolated from host | No isolation |
| **Namespace** | Own network namespace | Shares host namespace |
| **Network interfaces** | veth pair, virtual | Host interfaces directly |
| **IP address** | 172.17.x.x (Docker subnet) | Host IP (192.168.1.100) |
| **Port mapping** | Required (-p flag) | Not needed |
| **Performance** | Slight overhead (NAT) | Maximum performance |
| **Port conflicts** | Can map same port on different IPs | Only one container per port |
| **Use case** | Most applications | High-performance apps |
| **DNS** | Embedded Docker DNS | Host DNS |
| **External access** | Via port mapping | Direct access |

**Comparison:**

```bash
# Bridge Network
$ docker run -d -p 8080:80 nginx
# Access: http://localhost:8080
# Container IP: 172.17.0.2 (private)
# Host sees port 8080 forwarded to container

# Host Network
$ docker run -d --network host nginx
# Access: http://localhost:80
# Container IP: 192.168.1.100 (same as host)
# No port mapping, direct access to host ports
```

---

### **Q2: How does Docker DNS resolution work in custom networks?**

**A:**

**Architecture:**

```
Embedded DNS Server:
├─ Runs inside container
├─ Listens on 127.0.0.11:53 (non-standard)
├─ Only accessible from container
└─ Managed by Docker daemon

Container DNS Query:

1. Application (inside container):
   getaddrinfo("web", 0, NULL, &result)

2. glibc resolver:
   Query /etc/resolv.conf
   nameserver 127.0.0.11

3. Query to 127.0.0.11:53:
   Question: "web" type A

4. Docker embedded DNS (127.0.0.11):
   ├─ Check DNS cache
   ├─ Look in containers on same network
   ├─ Find container named "web"
   ├─ Get its IP: 172.18.0.2
   └─ Return A record: web → 172.18.0.2

5. glibc receives response:
   web = 172.18.0.2

6. Application gets address:
   Can now connect to 172.18.0.2

7. Connection established:
   TCP 172.18.0.2:80 → web container
```

**Implementation Details:**

```bash
# Inside container, DNS configuration
$ cat /etc/resolv.conf
nameserver 127.0.0.11
options ndots:0

# Docker injects this automatically
# 127.0.0.11 is Docker's DNS server
# ndots:0 means always query DNS first

# Query a container name
$ getent hosts web
172.18.0.2      web

# Query multiple records
$ nslookup web
Server:  127.0.0.11
Address: 127.0.0.11#53

Name: web
Address: 172.18.0.2

# Dig query (detailed)
$ dig web
web.  600  IN  A  172.18.0.2
```

**Default Bridge (No DNS):**

```bash
# Default bridge doesn't have embedded DNS for container names

$ cat /etc/resolv.conf
nameserver 8.8.8.8  # Google DNS
nameserver 8.8.4.4

# Can't resolve container names
$ ping web
ping: web: Name or address not known

# Must use IP
$ ping 172.17.0.2
PING 172.17.0.2

# Workaround: use --link (deprecated)
$ docker run --link web:web myapp
# Creates /etc/hosts entry mapping
# Allows: ping web
```

---

### **Q3: Explain port publishing internals with iptables.**

**A:**

**Port Publishing Setup:**

```bash
$ docker run -d -p 8080:80 nginx

# What Docker creates:

1. iptables PREROUTING rule:
iptables -t nat -A PREROUTING \
  -m addrtype --dst-type LOCAL \
  -j DOCKER

2. iptables DOCKER chain:
iptables -t nat -A DOCKER \
  -p tcp --dport 8080 \
  -j DNAT --to-destination 172.17.0.2:80

3. iptables FORWARD rule:
iptables -A FORWARD \
  -d 172.17.0.2 -p tcp --dport 80 \
  -m conntrack --ctstate NEW,ESTABLISHED \
  -j ACCEPT

4. iptables OUTPUT rule (for localhost):
iptables -t nat -A OUTPUT \
  -m addrtype --dst-type LOCAL \
  -j DOCKER

5. Container veth pair connected to docker0 bridge
```

**Request Flow with iptables:**

```
User Request: curl localhost:8080

1. Client connects to 127.0.0.1:8080
   TCP SYN packet:
   ├─ Source: 127.0.0.1:54321 (client)
   ├─ Destination: 127.0.0.1:8080 (host)
   └─ Flags: SYN

2. Host kernel receives on loopback (lo:8080)
   Routing decision: where to send?

3. PREROUTING hook (mangle/nat):
   ├─ Check if destination is LOCAL
   ├─ 127.0.0.1 is LOCAL ✓
   ├─ Jump to DOCKER chain
   └─ Continue

4. DOCKER chain rules:
   ├─ Match: -p tcp --dport 8080
   ├─ Jump to DNAT
   ├─ Destination NAT applied:
   │  Original: 127.0.0.1:8080
   │  New: 172.17.0.2:80
   └─ Conntrack records transformation

5. Modified packet:
   ├─ Source: 127.0.0.1:54321 (unchanged)
   ├─ Destination: 172.17.0.2:80 (changed!)
   └─ Flags: SYN

6. Routing decision:
   ├─ Destination is 172.17.0.2 (subnet 172.17.0.0/16)
   ├─ Route to docker0 bridge
   └─ Bridge will forward

7. FORWARD hook:
   ├─ Source: 127.0.0.1, Destination: 172.17.0.2
   ├─ Check: -d 172.17.0.2 -p tcp --dport 80
   ├─ State: NEW ✓
   ├─ Action: ACCEPT
   └─ Packet allowed

8. Bridge forwards packet:
   ├─ Destination MAC: container veth MAC
   ├─ Sends to veth pair
   └─ Packet in docker0 switch

9. Kernel transfers to container namespace:
   ├─ veth12345-br → veth12345
   ├─ Packet delivered to eth0
   └─ Container network stack receives

10. Container TCP stack:
    ├─ SYN packet on port 80
    ├─ Process (nginx) listening on 80
    ├─ SYN-ACK response created
    ├─ Response destination: original source
    │  Source: 172.17.0.2:80
    │  Destination: 127.0.0.1:54321
    └─ Send to eth0

11. Response packet exit container:
    ├─ Kernel transfers to host
    ├─ veth12345 → veth12345-br
    └─ Bridge receives

12. Response routing:
    ├─ Destination: 127.0.0.1:54321
    ├─ This is LOCAL (loopback)
    └─ Route to lo interface

13. POSTROUTING hook (reverse NAT):
    ├─ Conntrack recognizes response
    ├─ Reverse NAT applied:
    │  Source: 172.17.0.2:80 → 127.0.0.1:8080
    │  Destination: 127.0.0.1:54321 (unchanged)
    └─ (Source IP masqueraded back to original)

14. Response sent to client:
    ├─ Source: 127.0.0.1:8080
    ├─ Destination: 127.0.0.1:54321
    └─ Client receives response ✓

Connection established!
```

**View iptables Rules:**

```bash
# View NAT rules
$ iptables -t nat -L DOCKER

Chain DOCKER (2 references)
target     prot opt source   destination
DNAT       tcp  --  anywhere anywhere  tcp dpt:8080 to:172.17.0.2:80
DNAT       tcp  --  anywhere anywhere  tcp dpt:8081 to:172.17.0.3:80
DNAT       tcp  --  anywhere anywhere  tcp dpt:8082 to:172.17.0.4:3306

# View FORWARD rules
$ iptables -L DOCKER-INGRESS

Chain DOCKER-INGRESS
target     prot opt source  destination
ACCEPT     tcp  --  anywhere anywhere  tcp dpt:8080 ctstate NEW,ESTABLISHED
ACCEPT     tcp  --  anywhere anywhere  tcp dpt:8081 ctstate NEW,ESTABLISHED

# View all NAT rules
$ iptables -t nat -L -v

# View packet counts
$ iptables -t nat -L -v -n
```

**Connection Tracking (conntrack):**

```bash
# View active connections
$ conntrack -L

tcp      6 118 ESTABLISHED src=127.0.0.1 dst=172.17.0.2 \
sport=54321 dport=80 src=172.17.0.2 dst=127.0.0.1 \
sport=80 dport=54321 [ASSURED] mark=0 use=1

# Shows:
# - Connection state: ESTABLISHED
# - Original direction: client → server
# - Reply direction: server → client
# - NAT translations: [none explicit here, but recorded]
```

---

### **Q4: What happens when you connect a container to an additional network?**

**A:**

**Setup:**

```bash
# Create container on network 1
$ docker run -d --name web --network frontend nginx

# Container has:
# - eth0: 172.18.0.2 (on frontend network)
# - Connected to br-frontend bridge

# Connect to second network
$ docker network connect backend web

# Now container has:
# - eth0: 172.18.0.2 (on frontend network) - UNCHANGED
# - eth1: 172.19.0.2 (on backend network) - NEW
```

**What Docker Does:**

```
1. Find container:
   ├─ Get container ID
   ├─ Get network namespace
   └─ Verify container running

2. Allocate IP on new network:
   ├─ Network: backend (172.19.0.0/16)
   ├─ Find next available IP: 172.19.0.2
   ├─ Reserve in IPAM
   └─ Record in container metadata

3. Create veth pair:
   ├─ Host side: veth99999-br
   ├─ Container side: eth1
   └─ Link together

4. Connect host veth to bridge:
   ├─ Bridge: br-backend
   ├─ Add veth99999-br to bridge
   ├─ Update bridge MAC table
   └─ Bridge learns MAC address

5. Move container veth into namespace:
   ├─ Get container's network namespace
   ├─ ip link set eth1 netns <namespace>
   └─ eth1 now in container

6. Configure IP inside container:
   ├─ IP address: 172.19.0.2/16
   ├─ Gateway: 172.19.0.1 (br-backend)
   ├─ Route: 172.19.0.0/16 → eth1
   └─ Bring interface up

7. Update embedded DNS:
   ├─ Container can now reach backend network
   ├─ DNS resolves backend container names
   ├─ DNS resolves frontend container names (via eth0)
   └─ All on 127.0.0.11:53

8. Container now connected to both networks
```

**Container Perspective:**

```bash
$ docker exec web ip link show
1: lo: <LOOPBACK,UP,LOWER_UP>
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP>

$ docker exec web ip addr show
1: lo: inet 127.0.0.1/8
2: eth0: inet 172.18.0.2/16 (frontend)
3: eth1: inet 172.19.0.2/16 (backend)

$ docker exec web ip route show
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.0.2
172.19.0.0/16 dev eth1 proto kernel scope link src 172.19.0.2
```

**Communication Patterns:**

```
Container web can now reach:

Frontend network (via eth0):
├─ web: 172.18.0.2 (itself)
├─ db: 172.18.0.3 (if on frontend)
├─ cache: 172.18.0.4 (if on frontend)
└─ gateway: 172.18.0.1

Backend network (via eth1):
├─ worker: 172.19.0.3 (if on backend)
├─ queue: 172.19.0.4 (if on backend)
├─ processor: 172.19.0.5 (if on backend)
└─ gateway: 172.19.0.1

DNS resolution:
├─ ping db → 172.18.0.3 (frontend)
├─ ping worker → 172.19.0.3 (backend)
├─ Both work via embedded DNS
└─ DNS smart enough to know which network
```

**Disconnect from Network:**

```bash
# Remove from backend
$ docker network disconnect backend web

# Docker reverses the process:
1. Find eth1 (connected to backend)
2. Remove from bridge (br-backend)
3. Delete veth pair
4. Remove IP from IPAM
5. Update container metadata

# Container now only has:
# - eth0: 172.18.0.2 (frontend only)
# - eth1 deleted
```

---

### **Q5: What's the difference between named volumes and bind mounts?**

**A:**

| Aspect | Named Volume | Bind Mount |
|--------|---|---|
| **Location** | `/var/lib/docker/volumes/` | Any host path |
| **Management** | Docker-managed | User-managed |
| **Creation** | `docker volume create` | `docker run -v /host:/container` |
| **Portability** | High (easy to move) | Low (host-specific paths) |
| **Permissions** | Automatically set | Must manage manually |
| **Backup** | Easy with Docker API | Manual backup |
| **Sharing** | Between containers | Direct host access |
| **Performance** | Optimized | Direct filesystem |
| **Use case** | Production | Development |
| **Platform** | All (Windows, Mac, Linux) | Platform-dependent |

**Named Volume Example:**

```bash
# Create named volume
$ docker volume create mydata

# Use volume
$ docker run -d -v mydata:/app/data myapp

# Volume automatically mounted
# Docker manages mount point
# Can't see /app/data on host from outside Docker

# Only Docker knows location
$ docker volume inspect mydata
"Mountpoint": "/var/lib/docker/volumes/mydata/_data"

# Access via Docker, not directly
```

**Bind Mount Example:**

```bash
# Use host directory
$ docker run -d -v /home/user/data:/app/data myapp

# Directory mounted to /app/data in container
# Can access /home/user/data on host directly

$ ls /home/user/data
# See files written by container

# Host and container both access same files
# Direct filesystem, not Docker-managed
```

**Permissions Comparison:**

```
Named Volume (Docker-managed):
├─ Docker sets permissions automatically
├─ Default: 755 (rwxr-xr-x)
├─ Owner: root
├─ Container runs as any user (Docker handles mapping)
└─ Secure by default

Bind Mount (User-managed):
├─ Uses host filesystem permissions
├─ Must set permissions manually
├─ Must consider container user (usually root)
├─ Permission mismatch errors possible
└─ User responsible for security

Example permission issue:
Host: /home/user/data (owner: user, 755)
Container: runs as root (UID 0)
Docker: runs container as root in namespace
Result: Container can modify any file
Host user: can't delete container's files (owned by root)
```

**Development vs Production:**

```
Development (use bind mount):
$ docker run -d -v $(pwd):/app myapp
├─ Edit files on host
├─ Changes immediately visible in container
├─ Good for iterative development
├─ Easy to see logs, configs
└─ Source in version control

Production (use named volume):
$ docker run -d -v app-data:/data myapp
├─ Data isolated from host
├─ Easier to migrate/backup
├─ Docker-managed permissions
├─ Container has sole ownership
└─ Reproducible across hosts
```

---

### **Q6: How do you debug network issues in Docker?**

**A:**

**Diagnosis Tools:**

```bash
# 1. Check container network configuration
$ docker inspect mycontainer | grep -A 20 NetworkSettings

{
    "NetworkSettings": {
        "Bridge": "docker0",
        "Gateway": "172.17.0.1",
        "IPAddress": "172.17.0.2",
        "Networks": {
            "bridge": {
                "IPAddress": "172.17.0.2",
                "Gateway": "172.17.0.1"
            }
        }
    }
}

# 2. Check network configuration
$ docker network inspect bridge

# 3. View active connections
$ docker exec mycontainer netstat -tulpn

# 4. Check DNS resolution
$ docker exec mycontainer nslookup web
$ docker exec mycontainer cat /etc/resolv.conf

# 5. Check routing
$ docker exec mycontainer ip route show
$ docker exec mycontainer ip addr show

# 6. Test connectivity
$ docker exec mycontainer ping 172.17.0.1 (gateway)
$ docker exec mycontainer ping 8.8.8.8 (external)
$ docker exec mycontainer curl http://web (container name)
```

**Common Issues and Solutions:**

```
Issue 1: Container can't reach other containers

Diagnosis:
$ docker exec container1 ping container2
PING container2 (172.17.0.3) 56(84) bytes of data
(no response)

Check:
1. Both on same network?
   $ docker inspect container1 | grep NetworkMode
   $ docker inspect container2 | grep NetworkMode

2. DNS resolution works?
   $ docker exec container1 nslookup container2
   # Should return IP

3. Firewall rules?
   $ iptables -L INPUT -n
   $ iptables -L FORWARD -n

Solution:
├─ Verify on same custom network (not default bridge)
├─ Use custom network if not already
├─ Check iptables rules (--icc flag)
└─ Add both containers to same network


Issue 2: Container can't reach external network

Diagnosis:
$ docker exec mycontainer ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data
(no response)

Check:
1. Host can reach external?
   $ ping 8.8.8.8  # From host
   # Should work

2. Container routing?
   $ docker exec mycontainer ip route show
   # Should have default route

3. NAT rules?
   $ iptables -t nat -L -n
   # Should have rules

Solution:
├─ Check host connectivity
├─ Check container routing table
├─ Verify Docker daemon settings
├─ Check firewall (ufw, iptables)
└─ Restart Docker daemon if needed


Issue 3: Port mapping not working

Diagnosis:
$ docker run -d -p 8080:80 nginx
$ curl localhost:8080
curl: (7) Failed to connect

Check:
1. Port published?
   $ docker ps
   # Should show 0.0.0.0:8080->80/tcp

2. iptables rules?
   $ iptables -t nat -L DOCKER -n
   # Should show DNAT rule

3. Process listening?
   $ docker exec container netstat -tulpn
   # Should show listening on port 80

4. Firewall blocking?
   $ sudo ufw status
   # Check if port allowed

Solution:
├─ Verify iptables rules exist
├─ Check container process is listening
├─ Check host firewall
├─ Test with netcat: nc -zv localhost 8080
└─ Restart Docker daemon


Issue 4: DNS resolution fails

Diagnosis:
$ docker exec mycontainer nslookup web
Server:  127.0.0.11
Address: 127.0.0.11#53

** server can't find web: SERVFAIL

Check:
1. Custom network?
   # Default bridge doesn't have DNS
   $ docker network ls
   # Should be custom network, not "bridge"

2. Container on network?
   $ docker inspect mycontainer | grep NetworkMode
   # Should be custom network

3. DNS server running?
   $ netstat -tulpn | grep 53
   # Should see Docker DNS

Solution:
├─ Use custom bridge network
├─ Default bridge doesn't support DNS
├─ Reconnect container to custom network
└─ Use --link on default bridge (deprecated)
```

**Advanced Debugging:**

```bash
# 1. tcpdump inside container
$ docker run -it --rm --net container:mycontainer \
    nicolaka/netshoot tcpdump -i eth0

# 2. Full network trace
$ docker run -it --rm --net container:mycontainer \
    nicolaka/netshoot bash
$ tcpdump -i any -w /tmp/capture.pcap
$ wireshark /tmp/capture.pcap  # Analyze on host

# 3. Network namespace inspection
$ ip netns list  # List network namespaces
$ ip netns exec <namespace> ip addr show  # View namespace config

# 4. Bridge inspection
$ brctl show  # Show all bridges
$ brctl show docker0  # Show docker0 bridge details

# 5. iptables trace
$ iptables -t nat -L -v -n  # Detailed NAT rules
$ iptables -L FORWARD -v -n  # Forward rules
```

---

### **Q7: Best practices for production networking?**

**A:**

```
1. Use Custom Bridge Networks
   ├─ Always use custom networks, not default bridge
   ├─ Provides DNS resolution by container name
   ├─ Better isolation
   ├─ Easier service discovery
   └─ Recommended for all scenarios

2. Network Segmentation
   ├─ Frontend network (web servers)
   ├─ Backend network (databases, caches)
   ├─ Admin network (monitoring, logging)
   ├─ Separate networks by function
   └─ Improves security and troubleshooting

3. Port Publishing
   ├─ Only expose necessary ports
   ├─ Use specific port ranges
   ├─ Avoid exposing all ports
   ├─ Document exposed ports
   └─ Update firewall rules

4. Resource Limits
   ├─ Set memory limits
   ├─ Set CPU limits
   ├─ Monitor resource usage
   ├─ Alert on threshold breach
   └─ Plan capacity

5. Health Checks
   ├─ Use --health-cmd for liveness checks
   ├─ Restart unhealthy containers
   ├─ Monitor health status
   ├─ Alert on repeated failures
   └─ Document expected behavior

6. Load Balancing
   ├─ Use reverse proxy (nginx, HAProxy)
   ├─ Distribute across multiple containers
   ├─ Use health checks
   ├─ Monitor backend health
   └─ Failover to healthy instances

7. Logging
   ├─ Centralized logging (ELK, Splunk)
   ├─ Collect all container logs
   ├─ Correlate logs across services
   ├─ Alert on errors
   └─ Retain logs for analysis

8. Monitoring
   ├─ Monitor network metrics
   ├─ Track latency, throughput
   ├─ Alert on anomalies
   ├─ Dashboard for visibility
   └─ Analyze trends
```

---

### **Q8: Best practices for production volumes?**

**A:**

```
1. Use Named Volumes
   ├─ Always use named volumes for stateful data
   ├─ Easy to backup and restore
   ├─ Portable between containers
   ├─ Docker-managed permissions
   └─ Avoid ephemeral data loss

2. Backup Strategy
   ├─ Automated daily backups
   ├─ Off-site storage (cloud, external)
   ├─ Test restore procedures regularly
   ├─ Document backup/restore process
   └─ Verify backup integrity

3. Volume Drivers
   ├─ Use appropriate driver for infrastructure
   ├─ Local driver for single host
   ├─ NFS for multi-host
   ├─ Cloud storage for hybrid
   └─ Ensure high availability

4. Capacity Planning
   ├─ Monitor volume usage
   ├─ Plan for growth
   ├─ Alert at 80% capacity
   ├─ Add storage proactively
   └─ Don't wait until full

5. Performance
   ├─ Use local volumes for high I/O
   ├─ Consider tmpfs for caches
   ├─ Monitor I/O patterns
   ├─ Optimize mount options
   └─ Profile performance

6. Data Security
   ├─ Encrypt sensitive data
   ├─ Restrict volume access
   ├─ Use read-only mounts where possible
   ├─ Audit access logs
   └─ Secure backups

7. Disaster Recovery
   ├─ RPO (Recovery Point Objective): how much data can be lost?
   ├─ RTO (Recovery Time Objective): how long to recover?
   ├─ Test failover procedures
   ├─ Document recovery process
   └─ Maintain off-site copies

8. Monitoring
   ├─ Track volume usage trends
   ├─ Monitor I/O performance
   ├─ Alert on failures
   ├─ Metrics: space, throughput, latency
   └─ Dashboard for visibility
```

---

This comprehensive guide covers Docker Networks and Volumes with extensive Q&A coverage, just like the Engine and Runtime guide. Both are production-ready references for implementing and troubleshooting Docker infrastructure!
