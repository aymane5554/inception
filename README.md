_This project has been created as part of the 42 curriculum by ayel-arr_

# Description

This project, developed for the 42 curriculum, builds a small but complete WordPress stack with Docker Compose.

The stack includes:

- MariaDB for the database layer
- WordPress with PHP-FPM for the application layer
- Nginx as a reverse proxy with TLS enabled

Data is persisted through bind-mounted volumes, and the services are started and managed from the repository root with the provided Makefile.

## Features

- Dockerfiles for each service in the stack
- Docker Compose orchestration for the full environment
- Automatic MariaDB initialization and WordPress bootstrap
- Self-signed HTTPS certificate for Nginx
- Persistent storage for database and WordPress files

## Project Layout

- `srcs/docker-compose.yml` defines the services, network, and volumes
- `srcs/.env` contains the environment variables used by the containers
- `srcs/requirements/mariadb` contains the MariaDB image and bootstrap script
- `srcs/requirements/wordpress` contains the WordPress image and initialization script
- `srcs/requirements/nginx` contains the Nginx image and TLS configuration

## Requirements

- Docker and Docker Compose installed
- A Linux host that can run the containers
- A writable directory for persistent data

## Setup

1. Make sure Docker is installed and running.
2. Review `srcs/.env` and adapt the values to your environment if needed.
3. Ensure the host paths used for persistent data exist and are writable.
4. Run the stack from the repository root with `make`.

The current setup uses an absolute host path for persistent storage. If your home directory differs from the one encoded in the Makefile and compose file, update those paths before running the project.

## Instructions

Start the stack:

```bash
make
```

Stop the containers:

```bash
make down
```

Remove containers, networks, and unused Docker resources:

```bash
make clean
```

Full cleanup, including persisted data and Docker volumes:

```bash
make fclean
```

Rebuild everything from scratch:

```bash
make re
```

## Environment Variables

The stack reads its configuration from `srcs/.env`. The file defines:

- `DOMAIN_NAME`
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `WP_URL`
- `WP_TITLE`
- `WP_ADMIN_USER`
- `WP_ADMIN_PASSWORD`
- `WP_ADMIN_EMAIL`
- `WP_USER`
- `WP_PASSWORD`
- `WP_EMAIL`

## Concepts Covered

### Virtual Machines vs Docker Containers

Virtual machines virtualize an entire operating system on top of a hypervisor. They are heavier, start slower, and usually consume more disk and memory.

Docker containers share the host kernel and isolate applications at the process level. They are lighter, start quickly, and are a better fit when you want to package and run a service consistently across environments.

### Secrets vs Environment Variables

Environment variables are simple key-value pairs that are easy to inject into a container, which makes them convenient for non-sensitive configuration.

Secrets are meant for sensitive data such as passwords or tokens. They should be handled more carefully because they are intended to reduce accidental exposure compared to plain environment variables.

### Docker Network vs Host Network

A Docker bridge network gives containers their own isolated network space. Containers can reach each other by service name, and the host controls which ports are exposed.

The host network mode removes that isolation and lets a container share the host's network stack directly. It is simpler in some cases, but it reduces isolation and is less flexible.

### Docker Volumes vs Bind Mounts

Docker volumes are managed by Docker and are the preferred option for persistent application data because they are portable and easier to isolate from the host filesystem.

Bind mounts map a specific host directory into a container. They are useful when you want direct access to files on the host, but they depend on a fixed path and are more tightly coupled to the local machine.

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)