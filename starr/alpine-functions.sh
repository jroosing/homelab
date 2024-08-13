#!/bin/bash

# helper functions to handle setup of the starr stack
create_group() {
        if [ "$#" -ne 1 ]; then
                echo "Usage: create_group <groupname>"
                return 1
        fi

        local groupname="$1"

        # check if group already exists
        if getent group "$groupname" > /dev/null 2>&1; then
                echo "Group $groupname exists."
                return 0
        fi

        # create group if it does not exist
        doas addgroup "$groupname"
        echo "Group $groupname created."
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
                return 0
        fi

        # Create the user without a home directory, using the specified UID
        doas adduser -u "$uid" -G "$group" -D -H "$username"

        echo "User $username created with UID $uid and added to group $group."
}

# function to check if an entire path exists, and create it if it doesn't
ensure_path_exists() {
        if [ "$#" -ne 1]; then
                echo "Usage: ensure_path_exists <path>"
                return 1
        fi

        local path="$1"

        if [ -d "$path" ]; then
                echo "Path '$path' already exists. Skipping."
                return 0
        fi

        doas mkdir -pv "$path"
        echo "Path '$path' created."
}