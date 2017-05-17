#!/usr/bin/env bash
# Usage: {script} [ OPTIONS ] TARGET BUILD
# 
#   TARGET        Installation target. Default target is "/opt".
#   BUILD         Build number, e.g. 3126. If not defined uses a Sublime Text 3 
#                   web service to retrieve the latest stable or dev version number.
# 
# OPTIONS
#
#   -h, --help    Displays this help message.
#   -d, --dev     Install the dev version
#   -s, --stable  Install the stable version (default)
#
# Report bugs to Rudolf Bargholz <https://github.com/rudolfb/sublime-text-3-install>

# Based on a script by Henrique Moody
# https://gist.github.com/henriquemoody/3288681

# Unable to use "set -e" as one of the commands below fails and I do not know how to prevent this yet.
# set -e

if [[ "${1}" = '-h' ]] || [[ "${1}" = '--help' ]]; then
    sed -E 's/^#\s?(.*)/\1/g' "${0}" |
        sed -nE '/^Usage/,/^Report/p' |
        sed "s/{script}/$(basename "${0}")/g"
    exit
fi

# Echo shell commands as they are executed. Expands variables and prints a little + sign before the line.
# set -x

# ------------------------------------------------
# ------------------------------------------------
# --- Test sudo
# ------------------------------------------------
# This script uses the "sudo" command.
# Test to see if the user is able to elevate privileges by entering password for sudo.
# If the user is in sudo mode and this has not timed out yet, the script will continue.
# If the user does not enter a valid password, the script will exit.

declare CAN_I_RUN_SUDO="false"
$(sudo -v) && CAN_I_RUN_SUDO="true" || CAN_I_RUN_SUDO="false"

echo CAN_I_RUN_SUDO=$CAN_I_RUN_SUDO

if [ ${CAN_I_RUN_SUDO} == "true" ]; then
    echo "I can run the sudo command"
else
    echo "I can't run the sudo command."
    echo "This script requires sudo privileges."
    echo "The script will now teminate ...."
    exit
fi

# ------------------------------------------------
# ------------------------------------------------
# --- General purpose functions
# ------------------------------------------------

# Found the following code at
# http://git.openstack.org/cgit/openstack/gce-api/tree/install.sh
# It allows modifying values in an ini style file.

# Determines if the given option is present in the INI file
# ini_has_option config-file section option
function ini_has_option() {
    local file="$1"
    local section="$2"
    local option="$3"
    local line
    line=$(sudo sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    [ -n "$line" ]
}

# Set an option in an INI file
# iniset config-file section option value
function iniset() {
    local file="$1"
    local section="$2"
    local option="$3"
    local value="$4"
    if ! sudo grep -q "^\[$section\]" "$file"; then
        # Add section at the end
        sudo bash -c "echo -e \"\n[$section]\" >>\"$file\""
    fi
    if ! ini_has_option "$file" "$section" "$option"; then
        # Add it
        sudo sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        # Replace it
        sudo sed -i -e "/^\[$section\]/,/^\[.*\]/ s|^\($option[ \t]*=[ \t]*\).*$|\1$value|" "$file"
    fi
}

# ------------------------------------------------
# ------------------------------------------------
# --- Declare and define variables used below
# ------------------------------------------------

declare URL
declare URL_FORMAT="https://download.sublimetext.com/sublime_text_3_build_%d_x%d.tar.bz2"
#                   https://download.sublimetext.com/sublime_text_3_build_3126_x64.tar.bz2
declare VERSIONURL
declare VERSIONURL_FORMAT="http://www.sublimetext.com/updates/3/%s/updatecheck?platform=linux&arch=x%d"
#                          http://www.sublimetext.com/updates/3/dev/updatecheck?platform=linux&arch=x64
#                          http://www.sublimetext.com/updates/3/stable/updatecheck?platform=linux&arch=x64
declare PARAM_TARGET=""
declare TARGET="${1:-/opt}"
declare BUILD="${2}"
declare BITS
declare DEV_OR_STABLE="stable"
declare JSON

declare CURRENT_SUBL_LINK=""
declare CURRENT_SUBL_EXECUTABLE=""
declare CURRENT_SUBL_FOLDER=""

declare TEMPDIRECTORY=""
declare CWD=$(pwd)
declare SUBL_DESKTOP_FILE="/usr/share/applications/sublime_text.desktop"
declare SUBL_TARGET_FOLDER=""

# Set empty ("") to prevent debug echo information being displayed in the shell
# or "debug" to display the debug info.
declare DEBUG_ECHO=""

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo TARGET=$TARGET
    echo BUILD=$BUILD
    echo DEV_OR_STABLE=$DEV_OR_STABLE
    echo CWD=$CWD
    echo ...
fi

# ------------------------------------------------
# ------------------------------------------------
# --- Get command line parameters
# ------------------------------------------------

if [[ "${1}" = '-d' ]] || [[ "${1}" = '--dev' ]]; then
    DEV_OR_STABLE="dev"
    TARGET="${2:-/opt}"
    PARAM_TARGET="${2}"
    BUILD="${3}"
else
    if [[ "${1}" = '-s' ]] || [[ "${1}" = '--stable' ]]; then
        DEV_OR_STABLE="stable"
        TARGET="${2:-/opt}"
        PARAM_TARGET="${2}"
        BUILD="${3}"
    else
        DEV_OR_STABLE="stable"
        TARGET="${1:-/opt}"
        PARAM_TARGET="${1}"
        BUILD="${2}"
  fi
fi

# Check if the script is running on a 64-bit or 32-bit machine.
if [[ "$(uname -m)" = "x86_64" ]]; then
    BITS=64
else
    BITS=32
fi

# Use the Sublime Text web service to retrieve the latest version number of ST3.
if [[ -z "${BUILD}" ]]; then
    VERSIONURL=$(printf "${VERSIONURL_FORMAT}" "${DEV_OR_STABLE}" "${BITS}")
    JSON=$(wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 20 -O - ${VERSIONURL})
    BUILD=$(echo ${JSON} | grep -Po '"latest_version": \K[0-9]+')
fi

# Build the URL for the file that needs to be downloaded.
URL=$(printf "${URL_FORMAT}" "${BUILD}" "${BITS}")

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo DEV_OR_STABLE=$DEV_OR_STABLE
    echo TARGET=$TARGET
    echo PARAM_TARGET=$PARAM_TARGET
    echo BUILD=$BUILD
    echo BITS=$BITS
    echo VERSIONURL=$VERSIONURL
    echo JSON=$JSON
    echo CWD=$CWD
    echo ...
fi

# ------------------------------------------------
# ------------------------------------------------
# --- Check to see if Sublime Text is installed already
# ------------------------------------------------

# If Sublime Text 3 is installed, entering subl in a script will open Sublime Text.
# I can use this to find the location of the subl command, and then
# determine source file of the symbolic link.
# If the user has not specified a new install path
# then I can install into the already specified folder.

CURRENT_SUBL_LINK=$(type -p subl)
if [ ! -z "$CURRENT_SUBL_LINK" ]; then
  echo Sublime Text is already installed
  # The value of $CURRENT_SUBL_LINK is NOT empty
  CURRENT_SUBL_EXECUTABLE=$(readlink -f ${CURRENT_SUBL_LINK})
  CURRENT_SUBL_FOLDER=$(dirname "$CURRENT_SUBL_EXECUTABLE")
else
  echo Sublime Text is NOT installed
  # CURRENT_SUBL_FOLDER=/opt
fi

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo CURRENT_SUBL_LINK=$CURRENT_SUBL_LINK
    echo CURRENT_SUBL_EXECUTABLE=$CURRENT_SUBL_EXECUTABLE
    echo CURRENT_SUBL_FOLDER=$CURRENT_SUBL_FOLDER
    echo ...
fi

# Remove last directory from a string
# a="/dir1/dir2/dir3/dir4"
# echo ${a%/*}
# If the current install path is "/opt/sublime_text", then I need just the "/opt" as the TARGET.

# If PARAM_TARGET is empty, and CURRENT_SUBL_FOLDER is NOT empty ...
if [ -z "$PARAM_TARGET" ]; then
    if [ ! -z "$CURRENT_SUBL_FOLDER" ]; then
        TARGET="${CURRENT_SUBL_FOLDER%/*}"
    fi
fi

if [ "${DEBUG_ECHO}" == "debug" ]; then
  echo TARGET=$TARGET
  echo ...
fi

# ------------------------------------------------
# ------------------------------------------------
# --- Y/N continue installation
# ------------------------------------------------

read -p "Do you really want to install Sublime Text 3 (Build ${BUILD}, x${BITS}) in \"${TARGET}\"? [Y/n]: " CONFIRM
CONFIRM=$(echo "${CONFIRM}" | tr [a-z] [A-Z])
if [[ "${CONFIRM}" = 'N' ]] || [[ "${CONFIRM}" = 'NO' ]]; then
    echo "Aborted!"
    exit
fi

# ------------------------------------------------
# ------------------------------------------------
# --- Download, and extract in /tmp folder 
# ------------------------------------------------

# If the source folder is /opt, then the installation folder will be /opt/sublime_text
SUBL_TARGET_FOLDER="${TARGET}/sublime_text"

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo SUBL_TARGET_FOLDER=$SUBL_TARGET_FOLDER
    echo ...
fi

# Create a dynamic temporary directory and download the files into this directory.
# This directory is cleared when rebooting Linux.
TEMPDIRECTORY=$(mktemp --directory)

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo TEMPDIRECTORY=$TEMPDIRECTORY
    echo ...
fi

cd "$TEMPDIRECTORY"

Download the installation file, and unpack the file into the /tmp directory.
echo "Downloading Sublime Text 3 ..."
curl -L "${URL}" | tar -xjC ${TEMPDIRECTORY}

# Sublime Text 3 comes with a "sublime_text.desktop" file.
# If this file exists, delete the file.
if [ -f "$SUBL_DESKTOP_FILE" ]; then
    sudo rm "$SUBL_DESKTOP_FILE"
fi

# Copy the "sublime_text.desktop" from the unpacked installation file to the destination directory.
sudo cp -rf "sublime_text_3/sublime_text.desktop" "$SUBL_DESKTOP_FILE"

# Replace values in the sublime_text.desktop file to reference the installation folder TARGET
iniset $SUBL_DESKTOP_FILE "Desktop Entry" "Exec" "${SUBL_TARGET_FOLDER}/sublime_text %F"
iniset $SUBL_DESKTOP_FILE "Desktop Entry" "Icon" "${SUBL_TARGET_FOLDER}/Icon/128x128/sublime-text.png"
iniset $SUBL_DESKTOP_FILE "Desktop Action Window" "Exec" "${SUBL_TARGET_FOLDER}/sublime_text -n"
iniset $SUBL_DESKTOP_FILE "Desktop Action Document" "Exec" "${SUBL_TARGET_FOLDER}/sublime_text --command new_file"

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo Contents of ${SUBL_DESKTOP_FILE}:
    cat "$SUBL_DESKTOP_FILE"
fi

# If Sublime Text ist installed already, remove the current installation.
# The current install directory does not necessarily have to be the same as the 
# specified new installation directory.
if [ -d "$CURRENT_SUBL_FOLDER" ]; then
    sudo rm -r "$CURRENT_SUBL_FOLDER"
fi

if [ -d "$SUBL_TARGET_FOLDER" ]; then
    sudo rm -r "$SUBL_TARGET_FOLDER"
fi

# Move the unpacked application files from the temp folder to the destination directory.
sudo mv sublime_text_3 "${SUBL_TARGET_FOLDER}"

# Clean up the dynamically created temp directory.
if [ -d "$TEMPDIRECTORY" ]; then
    sudo rm -r "$TEMPDIRECTORY"
fi

# If a symlink exists, delete the current symlink and replace it with a new symlink
if [ -f "/usr/bin/subl" ] || [ -L "/usr/bin/subl" ]; then
    sudo rm "/usr/bin/subl"
    if [ "${DEBUG_ECHO}" == "debug" ]; then
        echo Removing symlink "/usr/bin/subl"
    fi    
fi

if [ -f "/usr/bin/subl" ]; then
    echo symlink still exists
fi

if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo Adding symlink "/usr/bin/subl"
fi
sudo ln -s "${SUBL_TARGET_FOLDER}/sublime_text" /usr/bin/subl

cd "$CWD"
if [ "${DEBUG_ECHO}" == "debug" ]; then
    echo CWD=$CWD
fi

echo --------------------------------------------------------------
echo "Finished installing!"
echo "Type \"subl\" in the shell to open Sublime Text 3."
echo "If you chose the dev version, you will need a serial number."
echo --------------------------------------------------------------

