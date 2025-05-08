# Docker Stack for Authentik, Synapse, and Livekit
==============================================

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Variables](#variables)
3. [Notes](#notes)

## Prerequisites
To deploy this stack, you need to have the following installed:
- Podman
- Docker Compose (compatibility layer for Podman)

## Variables
The following environment variables are used in the deployment script:
- `DOMAIN_NAME`: The domain name for your Authentik instance
- `MATRIX_SERVER_NAME`: The FQDN for your Matrix (Synapse) server
- `ECBACKEND_SUBNET`: The subnet address for the backend network (default: `172.21.0.1/24`)
- `POSTGRES_USER`: The username for the Synapse database (default: `synapse`)
- `POSTGRES_PASSWORD`: The password for the Synapse database (randomly generated if not provided)
- `AUTHENTIK_SECRET_KEY`: The secret key for Authentik (randomly generated)
- `LIVEKIT_KEY` and `LIVEKIT_SECRET`: The key and secret for Livekit (randomly generated)

## Notes
- The deployment script creates two networks: `call_ecbackend` and `call_proxy`.
- It also creates several volumes for data persistence.
- The script loads several Docker images, including Authentik, Element, JWT Service, Livekit, Postgres, Redis, Synapse, and Traefik.
- The `podman-compose up -d` command starts the stack in detached mode.
- The script waits for 60 seconds to allow the stack to start, then executes several commands to set permissions and restart the Synapse service.
- The final output shows the deployment environment variables, excluding passwords and secrets.
