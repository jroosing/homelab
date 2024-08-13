#!/bin/bash

# !!! - Set up your .env file BEFORE running this script - !!!

# Export all variables from .env.
# This is always going to complain about UID being a read-only variable.
# However that is not a problem and it's necessary for UID to be defined in the .env so that compose.yml can take it.
set -a
source .env
set +a

# include useful functions such as create_group and create_user
source ../functions.sh

# Create group and users
# Reboot is recommended after running this script to make sure all changes take effect
create_group homepage "${HOMEPAGE_GID}"
create_user homepage "${HOMEPAGE_UID}" "homepage"

# Create directories for the *arr setup
# ${ROOT_DIR:-.}/ means take the value from ROOT_DIR, or place in current dir
# Application configuration directories
ensure_path_exists ${ROOT_DIR:-.}/config

# Ensure correct permissions are set
sudo chown -R homepage:homepage ${ROOT_DIR:-.}/

echo "Done! It is recommended to reboot now."

