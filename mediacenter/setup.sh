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
create_group mediacenter "${MEDIACENTER_GID}"

create_user rclone "${RCLONE_UID}" "mediacenter"
create_user sonarr "${SONARR_UID}" "mediacenter"
create_user radarr "${RADARR_UID}" "mediacenter"
create_user recyclarr "${RECYCLARR_UID}" "mediacenter"
create_user prowlarr "${PROWLARR_UID}" "mediacenter"
create_user overseerr "${OVERSEERR_UID}" "mediacenter"
create_user "plex" "${PLEX_UID}" "mediacenter"
create_user "rdtclient" "${RDTCLIENT_UID}" "mediacenter"
create_user "bazarr" "${BAZARR_UID}" "mediacenter"
create_user "autoscan" "${AUTOSCAN_UID}" "mediacenter"

# Create directories for the *arr setup
# ${ROOT_DIR:-.}/ means take the value from ROOT_DIR, or place in current dir
# Application configuration directories
ensure_path_exists ${ROOT_DIR:-.}/config/{sonarr,radarr,recyclarr,prowlarr,overseerr,plex,rdtclient,bazarr,autoscan}
# Symlink directories
ensure_path_exists ${ROOT_DIR:-.}/data/symlinks/{radarr,sonarr}
# Location symlinks resolve to
ensure_path_exists ${ROOT_DIR:-.}/data/realdebrid-zurg
# Media folders.
ensure_path_exists ${ROOT_DIR:-.}/data/media/{movies,tv}

# Set permissions
# Recursively chmod to 775/664
sudo chmod -R a=,a+rX,u+w,g+w ${ROOT_DIR:-.}/data/
sudo chmod -R a=,a+rX,u+w,g+w ${ROOT_DIR:-.}/config/

sudo chown -R $UID:mediacenter ${ROOT_DIR:-.}/data/
sudo chown -R $UID:mediacenter ${ROOT_DIR:-.}/config/
sudo chown -R sonarr:mediacenter ${ROOT_DIR:-.}/config/sonarr
sudo chown -R radarr:mediacenter ${ROOT_DIR:-.}/config/radarr
sudo chown -R recyclarr:mediacenter ${ROOT_DIR:-.}/config/recyclarr
sudo chown -R prowlarr:mediacenter ${ROOT_DIR:-.}/config/prowlarr
sudo chown -R overseerr:mediacenter ${ROOT_DIR:-.}/config/overseerr
sudo chown -R plex:mediacenter ${ROOT_DIR:-.}/config/plex
sudo chown -R rdtclient:mediacenter ${ROOT_DIR:-.}/config/rdtclient
sudo chown -R bazarr:mediacenter ${ROOT_DIR:-.}/config/bazarr
sudo chown -R autoscan:mediacenter ${ROOT_DIR:-.}/config/autoscan

echo "Done! It is recommended to reboot now."