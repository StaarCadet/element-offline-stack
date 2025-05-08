#!/bin/bash

#Collect User Input for env variables
read -p "Enter your Domain Name: " DOMAIN_NAME
read -p "Enter your Matrix(synapse) FQDN: " MATRIX_SERVER_NAME
read -p "Enter your backend Network Subnet address [172.21.0.1/24]: " ECBACKEND_SUBNET
read -p "Enter your Synapse Database Username [synapse]: " POSTGRES_USER
read -s -p "Enter your Synapse Database Password: " POSTGRES_PASSWORD

#Set defaults if no user input
ECBACKEND_SUBNET=${ECBACKEND_SUBNET:-172.21.0.1/24}
POSTGRES_USER=${POSTGRES_USER:-synapse}
AUTHENTIK_ERROR_REPORTING__ENABLED=${AUTHENTIK_ERROR_REPORTING__ENABLED:-false}
DOMAIN_NAME=${DOMAIN_NAME:?Domain Name Required}
#Echo to environment files
echo "DOMAIN_NAME=$DOMAIN_NAME" >> .env
sed -i "s|domain:.*|domain: $DOMAIN_NAME|" ./backend/dev_livekit.yaml
echo "MATRIX_SERVER_NAME=$MATRIX_SERVER_NAME" >> .env
#Authentik
echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
echo "AUTHENTIK_ERROR_REPORTING__ENABLED=false" >> .env
echo "AUTHENTIK_DISABLE_STARTUP_ANALYTICS=true" >> .env
echo "AUTHENTIK_DISABLE_UPDATE_CHECK=true" >> .env
#Livekit
LIVEKIT_KEY=$(openssl rand -base64 36 | tr -d '\n')
echo "LIVEKIT_KEY=$LIVEKIT_KEY" >> .env
sed -i "s|key:.*|key: $LIVEKIT_KEY|" ./backend/dev_livekit.yaml
sed -i "s|shared_secret.*|shared_secret: $LIVEKIT_KEY|" ./backend/homeserver.yaml
LIVEKIT_SECRET=$(openssl rand -base64 36 | tr -d '\n')
echo "LIVEKIT_SECRET=$LIVEKIT_SECRET" >> .env
sed -i "s|secret:.*|secret: $LIVEKIT_SECRET|" ./backend/dev_livekit.yaml
#Synapse
echo "POSTGRES_USER=$POSTGRES_USER" >> .env
if [[ -z "$POSTGRES_PASSWORD" ]]
    then
        POSTGRES_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z' | head -c 36)
        echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
        sed -i "s|password:.*|password: $POSTGRES_PASSWORD|" ./backend/homeserver.yaml
    else
        echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
        sed -i "s|password:.*|password: $POSTGRES_PASSWORD|" ./backend/homeserver.yaml
fi
#Export Subnet Address for local host to use
export ECBACKEND_SUBNET

if ! podman network inspect call_ecbackend &>/dev/null; then
    echo "call_ecbackend network not found. Creating it now..."
    podman network create --driver bridge --subnet "$ECBACKEND_SUBNET" call_ecbackend
    if [[ $? -eq 0 ]]; then
        echo "Network call_ecbackend created successfully."
    else
        echo "Failed to create network call_ecbackend."
        exit 1
    fi
else
    echo "Network call_ecbackend already exists."
fi

if ! podman network inspect call_proxy &>/dev/null; then
    echo "call_proxy network not found. Creating it now..."
    podman network create --driver bridge call_proxy
    if [[ $? -eq 0 ]]; then
        echo "call_proxy network created successfully."
    else
        echo "Failed to create network call_proxy."
        exit 1
    fi
else
    echo "Network call_proxy already exists."
fi

VOLUMES=("synapse" "postgres" "database" "redis")

for VOLUME in "${VOLUMES[@]}"; do
    if ! podman volume inspect "$VOLUME" &>/dev/null; then
        echo "Volume '$VOLUME' not found. Creating it now..."
        podman volume create "$VOLUME"
        echo "Volume '$VOLUME' created successfully."
    else
        echo "Volume '$VOLUME' already exists."
    fi
done

echo "Loading Images..."
podman load -q -i authentik.tar
podman tag e3c993bbf4f6 ghcr.io/goauthentik/server:2025.2.4
podman load -q -i element.tar
podman tag ca82480cdc7e docker.io/vectorim/element-web:latest
podman load -q -i jwt.tar
podman tag e827e75947a1 ghcr.io/element-hq/lk-jwt-service:latest-ci
podman load -q -i livekit.tar
podman tag ebb78c6e151b livekit/livekit-server:latest
podman load -q -i postgres.tar
podman tag 1e753aa9bf0a cgr.dev/chainguard/postgres:latest
podman load -q -i redis.tar
podman tag 7c27b70e480f cgr.dev/chainguard/redis:latest
podman load -q -i synapse-patched2.tar
podman tag 01a6aa865c6f docker.io/matrixdotorg/synapse:latest
podman load -q -i traefik.tar
podman tag e94799fce514 traefik:latest
echo "Starting Stack..."
podman-compose up -d
sleep 60
podman exec synapse sh -c "chmod 775 /"
sleep 10
podman exec synapse sh -c "chmod -R 775 /data"
sleep 10
podman exec synapse sh -c "chmod -R 777 /data/homeserver.log"
podman-compose restart synapse
echo "Stack Started!"
echo "Deployment environment:"
grep -v 'PASSWORD\|SECRET' .env