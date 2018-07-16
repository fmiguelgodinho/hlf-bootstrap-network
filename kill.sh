#!/bin/bash
set -e

# Shut down the Docker containers that might be currently running.
docker rm $(docker ps -aq) -f

# remove any docker images related to existing containers
docker rmi $(docker images --filter=reference="dev-peer*" -q)

# prune network and volume
docker network prune -f
docker volume prune -f
