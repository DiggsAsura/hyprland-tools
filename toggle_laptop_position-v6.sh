#!/bin/bash

# --- Script Description ---
# This script toggles the display position between a laptop's internal display
# and a connected external display in a Hyprland environment.
# It supports both horizontal (left/right) and vertical (top/bottom) arrangements.
#
# Usage:
#   ./toggle_laptop_position.sh -h   (to toggle horizontal layout)
#   ./toggle_laptop_position.sh -v   (to toggle vertical layout)
#
# It automatically detects the external monitor's properties (name, resolution, refresh rate).
# If the external monitor is detected as 4K (3840x2160), it applies a 1.5x scale;
# otherwise, a 1x scale is used. The laptop display is always scaled at 1x.
# Mouse cursor movement between displays is correctly handled by accounting for
# logical (scaled) display dimensions.

# --- Dependencies ---
# - hyprctl: For interacting with the Hyprland compositor.
# - jq:      For parsing JSON output from hyprctl.
# - bc:      For performing floating-point arithmetic (calculating logical dimensions).
# - head:    Standard utility, used for selecting the first external monitor.

# --- User Configuration ---
# Important: Set your laptop's internal display name here.
# You can find your display name by running `hyprctl monitors` in a terminal.
# Look for the name associated with your laptop's built-in screen.
# Common names include "eDP-1", "eDP-2", "LVDS-1", etc.
LAPTOP_DISPLAY_NAME="eDP-1"
# --- End of User Configuration ---

# --- Argument Parsing ---
MODE=""
if [ "$1" == "-h" ]; then
    MODE="horizontal"
elif [ "$1" == "-v" ]; then
    MODE="vertical"
else
    SCRIPT_NAME=$(basename "$0")
    echo "Usage: $SCRIPT_NAME [-h | -v]"
    echo "  -h: Toggle horizontal layout (monitors side-by-side)"
    echo "  -v: Toggle vertical layout (monitors stacked top/bottom)"
    exit 1
fi

# --- Script Logic ---

# Check if bc (basic calculator) is installed
if ! command -v bc &> /dev/null
then
    echo "Error: The command line calculator 'bc' is not installed."
    echo "Please install 'bc' (e.g., using your system's package manager) and try again."
    exit 1
fi

# Check if jq (JSON processor) is installed
if ! command -v jq &> /dev/null
then
    echo "Error: The JSON processor 'jq' is not installed."
    echo "Please install 'jq' (e.g., using your system's package manager) and try again."
    exit 1
fi

# Get all monitors in JSON format
MONITORS_JSON=$(hyprctl monitors -j)

# Get details for the configured laptop display
LAPTOP_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.name == "'"$LAPTOP_DISPLAY_NAME"'")')

if [ -z "$LAPTOP_MONITOR_INFO" ] || [ "$LAPTOP_MONITOR_INFO" == "null" ]; then
    echo "Error: Configured laptop display '$LAPTOP_DISPLAY_NAME' not found."
    echo "Please check the LAPTOP_DISPLAY_NAME variable in the script and ensure it matches a name from 'hyprctl monitors'."
    FIRST_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[0]')
    if [ ! -z "$FIRST_MONITOR_INFO" ] && [ "$FIRST_MONITOR_INFO" != "null" ] && [ "$(echo "$FIRST_MONITOR_INFO" | jq -r '.name')" != "null" ]; then
        FM_NAME=$(echo "$FIRST_MONITOR_INFO" | jq -r '.name'); FM_PHY_WIDTH=$(echo "$FIRST_MONITOR_INFO" | jq -r '.width'); FM_PHY_HEIGHT=$(echo "$FIRST_MONITOR_INFO" | jq -r '.height'); FM_REFRESH=$(echo "$FIRST_MONITOR_INFO" | jq -r '.refreshRate')
        FM_RES="${FM_PHY_WIDTH}x${FM_PHY_HEIGHT}@${FM_REFRESH}"; FM_SCALE="1"
        echo "Attempting to configure the first found monitor as a fallback: $FM_NAME, $FM_RES, 0x0, $FM_SCALE"
        hyprctl keyword monitor "$FM_NAME,$FM_RES,0x0,$FM_SCALE"
    else
        echo "No monitors found or unable to parse monitor information."
    fi
    exit 1
fi

LAPTOP_PHY_WIDTH=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.width')
LAPTOP_PHY_HEIGHT=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.height')
LAPTOP_REFRESH=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.refreshRate')
LAPTOP_RES="${LAPTOP_PHY_WIDTH}x${LAPTOP_PHY_HEIGHT}@${LAPTOP_REFRESH}"
LAPTOP_SCALE="1"
LOGICAL_LAPTOP_WIDTH=$(echo "scale=0; $LAPTOP_PHY_WIDTH / $LAPTOP_SCALE" | bc)
LOGICAL_LAPTOP_HEIGHT=$(echo "scale=0; $LAPTOP_PHY_HEIGHT / $LAPTOP_SCALE" | bc)


EXTERNAL_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.name != "'"$LAPTOP_DISPLAY_NAME"'")' | head -n 1)

if [ -z "$EXTERNAL_MONITOR_INFO" ] || [ "$EXTERNAL_MONITOR_INFO" == "null" ]; then
    echo "Info: No external display detected. Configuring laptop display ('$LAPTOP_DISPLAY_NAME') only."
    hyprctl keyword monitor "$LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE"
    exit 0
fi

EXTERNAL_DISPLAY_NAME=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.name')
EXTERNAL_PHY_WIDTH=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.width')
EXTERNAL_PHY_HEIGHT=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.height')
EXTERNAL_REFRESH=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.refreshRate')
EXTERNAL_RES="${EXTERNAL_PHY_WIDTH}x${EXTERNAL_PHY_HEIGHT}@${EXTERNAL_REFRESH}"

if [ "$EXTERNAL_DISPLAY_NAME" = "null" ] || [ "$EXTERNAL_PHY_WIDTH" = "null" ] || [ "$EXTERNAL_PHY_HEIGHT" = "null" ]; then
    echo "Error: Could not retrieve complete details for the external display."
    hyprctl keyword monitor "$LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE"
    exit 1
fi

EXTERNAL_SCALE="1"
if [ "$EXTERNAL_PHY_WIDTH" -eq 3840 ] && [ "$EXTERNAL_PHY_HEIGHT" -eq 2160 ]; then
    EXTERNAL_SCALE="1.5"
    echo "External display '$EXTERNAL_DISPLAY_NAME' is 4K (3840x2160). Setting scale to $EXTERNAL_SCALE."
else
    echo "External display '$EXTERNAL_DISPLAY_NAME' is not 4K. Setting scale to $EXTERNAL_SCALE."
fi
LOGICAL_EXTERNAL_WIDTH=$(echo "scale=0; $EXTERNAL_PHY_WIDTH / $EXTERNAL_SCALE" | bc)
LOGICAL_EXTERNAL_HEIGHT=$(echo "scale=0; $EXTERNAL_PHY_HEIGHT / $EXTERNAL_SCALE" | bc)


echo "Laptop ('$LAPTOP_DISPLAY_NAME'): $LAPTOP_RES, Scale: $LAPTOP_SCALE, Phys.W: $LAPTOP_PHY_WIDTH, Phys.H: $LAPTOP_PHY_HEIGHT, Logical.W: $LOGICAL_LAPTOP_WIDTH, Logical.H: $LOGICAL_LAPTOP_HEIGHT"
echo "External ('$EXTERNAL_DISPLAY_NAME'): $EXTERNAL_RES, Scale: $EXTERNAL_SCALE, Phys.W: $EXTERNAL_PHY_WIDTH, Phys.H: $EXTERNAL_PHY_HEIGHT, Logical.W: $LOGICAL_EXTERNAL_WIDTH, Logical.H: $LOGICAL_EXTERNAL_HEIGHT"

# --- Position Swapping Logic ---
if [ "$MODE" == "horizontal" ]; then
    STATE_FILE="/tmp/hyprland_laptop_pos_state_horizontal_dynamic"
    # 0 = External Left, Laptop Right; 1 = Laptop Left, External Right
    if [ ! -f "$STATE_FILE" ]; then echo "0" > "$STATE_FILE"; fi # Default: External Left
    CURRENT_STATE=$(cat "$STATE_FILE")

    if [ "$CURRENT_STATE" = "0" ]; then
        echo "Switching to HORIZONTAL: Laptop ('$LAPTOP_DISPLAY_NAME') LEFT, External ('$EXTERNAL_DISPLAY_NAME') RIGHT"
        hyprctl --batch "\
            keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE;\
            keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,${LOGICAL_LAPTOP_WIDTH}x0,$EXTERNAL_SCALE"
        echo "1" > "$STATE_FILE"
    else
        echo "Switching to HORIZONTAL: External ('$EXTERNAL_DISPLAY_NAME') LEFT, Laptop ('$LAPTOP_DISPLAY_NAME') RIGHT"
        hyprctl --batch "\
            keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,0x0,$EXTERNAL_SCALE;\
            keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,${LOGICAL_EXTERNAL_WIDTH}x0,$LAPTOP_SCALE"
        echo "0" > "$STATE_FILE"
    fi
elif [ "$MODE" == "vertical" ]; then
    STATE_FILE="/tmp/hyprland_laptop_pos_state_vertical_dynamic"
    # 0 = External Top, Laptop Bottom; 1 = Laptop Top, External Bottom
    if [ ! -f "$STATE_FILE" ]; then echo "0" > "$STATE_FILE"; fi # Default: External Top
    CURRENT_STATE=$(cat "$STATE_FILE")

    if [ "$CURRENT_STATE" = "0" ]; then
        echo "Switching to VERTICAL: Laptop ('$LAPTOP_DISPLAY_NAME') TOP, External ('$EXTERNAL_DISPLAY_NAME') BOTTOM"
        hyprctl --batch "\
            keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE;\
            keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,0x${LOGICAL_LAPTOP_HEIGHT},$EXTERNAL_SCALE"
        echo "1" > "$STATE_FILE"
    else
        echo "Switching to VERTICAL: External ('$EXTERNAL_DISPLAY_NAME') TOP, Laptop ('$LAPTOP_DISPLAY_NAME') BOTTOM"
        hyprctl --batch "\
            keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,0x0,$EXTERNAL_SCALE;\
            keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x${LOGICAL_EXTERNAL_HEIGHT},$LAPTOP_SCALE"
        echo "0" > "$STATE_FILE"
    fi
fi

echo "Monitor layout updated successfully. Current date: $(date)."
