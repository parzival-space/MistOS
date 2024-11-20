#!/bin/bash
set -e
#set -x

export GTK_THEME=Adwaita:dark

# depends: xterm zenity
function get_archive_url() {
    local BRANCH="$1"
    if [ "$1" = "" ]; then
        BRANCH="public"
    fi

    # fetch download url
    local OS_CODENAME=$(grep VERSION_CODENAME /etc/os-release | sed 's,.*=,,')
    local ARCH=$(dpkg --print-architecture)

    # test data
    local OS_CODENAME=bookworm
    local ARCH=armhf

    local MANIFEST_URL="https://media.steampowered.com/steamlink/rpi/$OS_CODENAME/$ARCH/${BRANCH}_build.txt"
    local MANIFEST_RESPONSE=$(curl -s -w "%{http_code}" $MANIFEST_URL)
    local MANIFEST_RESPONSE_CODE="${MANIFEST_RESPONSE: -3}"
    local MANIFEST_RESPONSE_MESSAGE="${MANIFEST_RESPONSE:0:${#MANIFEST_RESPONSE}-3}"

    if [ "$MANIFEST_RESPONSE_CODE" = "200" ]; then
        echo "$MANIFEST_RESPONSE_MESSAGE"
        return 0
    else
        echo ""
        return 1
    fi
}

function download_archive() {
    local ARCHIVE_URL="$1"
    local ARCHIVE_FILE="$2"
    mkdir -p "$(dirname $ARCHIVE_FILE)"

    local ARCHIVE_STATUS=$(curl -o "$ARCHIVE_FILE" -s -w "%{http_code}\n" "$ARCHIVE_URL")
    if [ "$ARCHIVE_STATUS" = "200" ]; then
        return 0
    else
        return 1
    fi
}

function install_steamlinkdeps() {
    local DEPENDENCY_FILE="$1"
    local DEPENDENCIES=()

    if [[ ! -f "$DEPENDENCY_FILE" ]]; then
        echo "File not found: $DEPENDENCY_FILE"
        return 1
    fi

    # Read the file and collect package names
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || "$line" =~ ^[A-Za-z_]+[A-Za-z0-9_]*=.*$ || -z "$line" ]] && continue

        # Add package name to the array
        DEPENDENCIES+=("$line")
    done < "$DEPENDENCY_FILE"

    sudo apt-get install -y ${DEPENDENCIES[@]}
}


# info
STEAMLINK_FILE="steamlink.sh"
STEAMLINK_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/SteamLink"

# fetch package archive url for current platform
ARCHIVE_URL=$(get_archive_url "public")
if [ $? == 0 ]; then
    # manifest found, try loading last package url
    LAST_ARCHIVE_URL=""
    if [ -f "$STEAMLINK_DATA_HOME/.archive_url" ]; then
        LAST_ARCHIVE_URL="$(cat "$STEAMLINK_DATA_HOME/.archive_url")"
    fi

    if [ "$ARCHIVE_URL" != "$LAST_ARCHIVE_URL" ]; then
        # update needed
        (
            echo "#Downloading steamlink.tar.gz..."
            PACKAGE_FILE="$STEAMLINK_DATA_HOME/.tmp/steamlink.tar.gz"
            mkdir -p "$(dirname $PACKAGE_FILE)"
            if download_archive "$ARCHIVE_URL" "$PACKAGE_FILE"; then
                echo "10"

                # download success
                tar -xf "$PACKAGE_FILE" -C "$STEAMLINK_DATA_HOME/.tmp/"
                echo "30"

                if [ -f "$STEAMLINK_DATA_HOME/.tmp/steamlink/$STEAMLINK_FILE" ]; then
                    # update valid

                    # backup old install
                    echo "#Creating Backup..."
                    BACKUP_DIR="$STEAMLINK_DATA_HOME/.old"
                    rm -rf "$BACKUP_DIR"
                    mkdir -p "$BACKUP_DIR"
                    find "$STEAMLINK_DATA_HOME" -mindepth 1 -maxdepth 1 ! -name ".old" ! -name ".tmp" -exec cp -r {} "$BACKUP_DIR" \;
                    echo "40"

                    # update files
                    echo "#Installing Updates..."
                    find "$STEAMLINK_DATA_HOME" -mindepth 1 -maxdepth 1 ! -name ".old" ! -name ".tmp" -exec rm -rf {} +
                    cp -r "$STEAMLINK_DATA_HOME/.tmp/steamlink/"* "$STEAMLINK_DATA_HOME"
                    echo "60"

                    # store version url & patch steamlink.sh
                    echo "#Applying Patches..."
                    echo "$ARCHIVE_URL" > "$STEAMLINK_DATA_HOME/.archive_url"
                    sed -i 's/read input//g' "$STEAMLINK_DATA_HOME/steamlink.sh"
                    echo "70"

                    echo "#Installing Dependencies... This may take a while."
                    install_steamlinkdeps "$STEAMLINK_DATA_HOME/steamlinkdeps.txt"
                    echo "95"
                else
                    # update invalid
                    echo "#Couldn't find $STEAMLINK_FILE in update, ignoring..."
                    rm -rf "$(dirname $PACKAGE_FILE)"
                fi

                echo "#Cleanup..."
                rm -rf "$STEAMLINK_DATA_HOME/.tmp/"
            else
                echo "#Failed to download update."
            fi
        ) | zenity --progress \
            --title="Updating Steam Link" \
            --text="Loading..." \
            --width=350 \
            --percentage=0 \
            --time-remaining \
            --auto-close \
            --no-cancel
    else
        echo "No update available."
    fi
else
    zenity --error --title="MistOS" --text="Couldn't find a matching manifest for the current platform."
fi

# launch SteamLink
if [ -x "$STEAMLINK_DATA_HOME/$STEAMLINK_FILE" ]; then
    "$STEAMLINK_DATA_HOME/$STEAMLINK_FILE" "$@"

    # reboot the device if requested
    if [[ " $@ " == *" --shutdown-on-exit "* ]]; then
        sudo /usr/bin/systemctl -i poweroff
    fi
else
    zenity --error --title="MistOS" --text="Couldn't download Steam Link application, aborting"
fi
