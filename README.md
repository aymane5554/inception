_This project has been created as part of the 42 curriculum by ayel-arr_

## Description

Inception is a comprehensive Docker infrastructure project that demonstrates containerization best practices, orchestration with Docker Compose, and modern DevOps workflows. This project creates a complete web stack running in isolated containers, managing services, volumes, and networking securely.

## Instructions

### Prerequisites
- Docker and Docker Compose installed on your system
- GNU Make
- Basic understanding of Docker, containers, and Docker Compose

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd inception
   ```

2. **Set up environment files:**
   ```bash
   make setup
   ```

3. **Build and start the infrastructure:**
   ```bash
   make build
   make up
   ```

4. **Access the services:**
   - Website: http://localhost
   - Admin Panel: http://localhost/wp-admin

5. **Stop the infrastructure:**
   ```bash
   make down
   ```

### Available Make Commands
- `make setup` - Initialize environment and configuration files
- `make build` - Build all Docker images
- `make up` - Start all services in the background
- `make down` - Stop all running services
- `make ps` - Show status of running containers
- `make logs` - View container logs
- `make clean` - Remove containers and volumes
- `make fclean` - Full cleanup including images

## Resources

### Docker Concepts
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Guide](https://docs.docker.com/compose/)
- [Docker Networking](https://docs.docker.com/network/)
- [Docker Volumes](https://docs.docker.com/storage/volumes/)

### Infrastructure Components
- **Nginx**: Reverse proxy and web server
- **WordPress**: Content management system
- **MariaDB**: Relational database
- **Redis**: In-memory data store (optional)

## Project Description

This project explores essential Docker and DevOps concepts through a practical, production-like setup:

### Virtual Machines vs Docker
- **VMs**: Full OS emulation with significant overhead
- **Docker**: Lightweight containers sharing the host kernel, faster startup, lower resource usage
- **Use Case**: Docker for microservices and rapid deployment; VMs for full OS isolation

### Secrets vs Environment Variables
- **Environment Variables**: Suitable for non-sensitive configuration (URLs, ports, settings)
- **Secrets**: For sensitive data (database passwords, API keys) stored securely outside the codebase
- **Best Practice**: Use Docker secrets in swarm mode or .env files excluded from version control

### Docker Network vs Host Network
- **Docker Network (bridge)**: Containers on isolated network, can map ports to host
- **Host Network**: Container shares host's network stack, no port mapping needed but less isolation
- **Use Case**: Bridge for multi-container apps; host for performance-critical applications

### Docker Volumes vs Bind Mounts
- **Volumes**: Docker-managed storage, better performance, portable across hosts
- **Bind Mounts**: Direct host directory mounted in container, useful for development
- **Use Case**: Volumes for production databases; bind mounts for development and source code

### Architecture Overview

```
┌─────────────────────────────────────────┐
│         Docker Network                  │
├─────────────┬───────────────┬──────────┤
│   Nginx     │   WordPress   │ MariaDB  │
│ (Port 443)  │   (Port 9000) │ (Port   │
│             │               │  3306)   │
└─────────────┴───────────────┴──────────┘
       │              │            │
    Volumes for SSL, Config, WordPress, Database
```

### Security Features
- SSL/TLS encryption for web traffic
- Database credentials stored in .env file
- Isolated network for inter-container communication
- Non-root containers where possible
- Secrets managed separately from application code
