#!/bin/bash

set -e

# helper functions to handle setup of the starr stack
create_group() {
        if [ "$#" -ne 2 ]; then
                echo "Usage: create_group <groupname> <group uid>"
                return 1
        fi

        local groupname="$1"
        local gid="$2"

        # Check if the group already exists
        if getent group "$groupname" >/dev/null 2>&1; then
                echo "Group $groupname exists."
        else
                # Create group if it does not exist
                sudo groupadd "$groupname" -g "$gid"
                echo "Group $groupname created."
        fi
}

create_user() {
        if [ "$#" -ne 3 ]; then
                echo "Usage: create_user <username> <uid> <group>"
                return 1
        fi

        local username="$1"
        local uid="$2"
        local group="$3"

        # Check if the user already exists
        if id "$username" &>/dev/null; then
                echo "User $username already exists. Skipping."
        else
                # Create the user and add to specified group
                sudo useradd "$username" -u "$uid"
                sudo usermod -aG "$group" "$username"

                echo "User $username created with UID $uid and added to group $group."
        fi
}

# function to check if an entire path exists, and create it if it doesn't
ensure_path_exists() {
        if [ "$#" -lt 1 ]; then
                echo "Usage: ensure_path_exists <path>"
                return 1
        fi

        for dir in "$@"; do
                if [ -d "$dir" ]; then
                        echo "Path '$dir' already exists. Skipping."
                        continue
                fi
                sudo mkdir -pv "$dir"
        done
}
