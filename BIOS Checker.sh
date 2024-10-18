#!/bin/sh
# HELP: BIOS Checker
# ICON: bios

# Application icon should be installed in themes to be used in the Application menu.
# theme/glyph/muxapp/bios.png

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

# Define Paths
LOVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.bioschecker"
GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
CONF_DIR="$LOVE_DIR/conf"

# Export Environment Variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export LD_LIBRARY_PATH="$LOVE_DIR/libs:$LD_LIBRARY_PATH"

# Launch Application
cd "$LOVE_DIR" || exit

SET_VAR "system" "foreground_process" "love"

$GPTOKEYB "$LOVE_DIR/love" -c "$CONF_DIR/love.gptk" &
./love ./program

# Cleanup
kill -9 $(pidof gptokeyb2)
kill -9 $(pidof love)