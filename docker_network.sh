#!/bin/bash

# Define the network
NETWORK_NAME="homelab"

# Check if the network already exists
if docker network ls --filter name="^${NETWORK_NAME}$" --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
  echo "Docker network '${NETWORK_NAME}' already exists. Skipping."
  exit 0
fi

# Create the network if it doesn't exist
docker network create "${NETWORK_NAME}"
echo "Docker network '${NETWORK_NAME}' created."