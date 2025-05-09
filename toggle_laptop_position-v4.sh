#!/bin/bash

# Dependencies:
# - hyprctl: For interacting with the Hyprland compositor.
# - jq:      For parsing JSON output from hyprctl.
# - bc:      For performing floating-point arithmetic (calculating logical widths).
# - head:    Standard utility, used for selecting the first external monitor.

# --- Configuration ---
LAPTOP_DISPLAY_NAME="eDP-1" # Name of your laptop's internal display

# --- Script Logic ---

# Check if bc (basic calculator) is installed
if ! command -v bc &> /dev/null
then
    echo "Error: The command line calculator 'bc' is not installed."
    echo "Please install 'bc' (e.g., sudo apt install bc) and try again."
    exit 1
fi

# Check if jq (JSON processor) is installed
if ! command -v jq &> /dev/null
then
    echo "Error: The JSON processor 'jq' is not installed."
    echo "Please install 'jq' (e.g., sudo apt install jq) and try again."
    exit 1
fi

# Get all monitors in JSON format
MONITORS_JSON=$(hyprctl monitors -j)

# Get details for the laptop display (eDP-1)
LAPTOP_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.name == "'"$LAPTOP_DISPLAY_NAME"'")')

# Handle case where laptop display might not be found (should be rare if run on the laptop)
if [ -z "$LAPTOP_MONITOR_INFO" ] || [ "$LAPTOP_MONITOR_INFO" == "null" ]; then
    echo "Error: Laptop display '$LAPTOP_DISPLAY_NAME' not found."
    # Attempt to configure only the first available monitor if eDP-1 is not found by that name
    # This part might need adjustment based on how a solo, non-eDP-1 monitor should be handled
    FIRST_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[0]')
    if [ ! -z "$FIRST_MONITOR_INFO" ] && [ "$FIRST_MONITOR_INFO" != "null" ]; then
        FM_NAME=$(echo "$FIRST_MONITOR_INFO" | jq -r '.name')
        FM_PHY_WIDTH=$(echo "$FIRST_MONITOR_INFO" | jq -r '.width')
        FM_PHY_HEIGHT=$(echo "$FIRST_MONITOR_INFO" | jq -r '.height')
        FM_REFRESH=$(echo "$FIRST_MONITOR_INFO" | jq -r '.refreshRate')
        FM_RES="${FM_PHY_WIDTH}x${FM_PHY_HEIGHT}@${FM_REFRESH}"
        FM_SCALE="1" # Assume scale 1 for a solo unknown monitor
        echo "Attempting to configure the first found monitor: $FM_NAME, $FM_RES, 0x0, $FM_SCALE"
        hyprctl keyword monitor "$FM_NAME,$FM_RES,0x0,$FM_SCALE"
    fi
    exit 1
fi

# Laptop display physical dimensions and refresh rate
LAPTOP_PHY_WIDTH=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.width')
LAPTOP_PHY_HEIGHT=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.height')
LAPTOP_REFRESH=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.refreshRate')
LAPTOP_RES="${LAPTOP_PHY_WIDTH}x${LAPTOP_PHY_HEIGHT}@${LAPTOP_REFRESH}"
LAPTOP_SCALE="1" # Laptop display scale is always 1 for this script's logic
# Calculate logical width for the laptop display
LOGICAL_LAPTOP_WIDTH=$(echo "scale=0; $LAPTOP_PHY_WIDTH / $LAPTOP_SCALE" | bc)


# Attempt to find an active external display (any display that is not the laptop display)
# Takes the first one found if multiple external displays are connected.
EXTERNAL_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.name != "'"$LAPTOP_DISPLAY_NAME"'")' | head -n 1)

# If no external display is found, configure only the laptop display and exit
if [ -z "$EXTERNAL_MONITOR_INFO" ] || [ "$EXTERNAL_MONITOR_INFO" == "null" ]; then
    echo "Info: No external display detected. Configuring laptop display only."
    echo "Configuring: $LAPTOP_DISPLAY_NAME, $LAPTOP_RES, 0x0, $LAPTOP_SCALE"
    hyprctl keyword monitor "$LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE"
    exit 0
fi

# External display details
EXTERNAL_DISPLAY_NAME=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.name')
EXTERNAL_PHY_WIDTH=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.width')
EXTERNAL_PHY_HEIGHT=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.height')
EXTERNAL_REFRESH=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.refreshRate')
EXTERNAL_RES="${EXTERNAL_PHY_WIDTH}x${EXTERNAL_PHY_HEIGHT}@${EXTERNAL_REFRESH}"

# Check if all necessary external display details were retrieved
if [ "$EXTERNAL_DISPLAY_NAME" = "null" ] || [ "$EXTERNAL_PHY_WIDTH" = "null" ] || [ "$EXTERNAL_PHY_HEIGHT" = "null" ]; then
    echo "Error: Could not retrieve complete details for the external display."
    echo "Detected Name: $EXTERNAL_DISPLAY_NAME, Physical Width: $EXTERNAL_PHY_WIDTH, Physical Height: $EXTERNAL_PHY_HEIGHT"
    echo "Configuring laptop display only as a fallback."
    hyprctl keyword monitor "$LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE"
    exit 1
fi

# Determine scaling factor for the external display
EXTERNAL_SCALE="1" # Default scale
# Specifically check for 4K UHD resolution (3840x2160)
if [ "$EXTERNAL_PHY_WIDTH" -eq 3840 ] && [ "$EXTERNAL_PHY_HEIGHT" -eq 2160 ]; then
    EXTERNAL_SCALE="1.5"
    echo "External display is 4K (3840x2160). Setting scale to $EXTERNAL_SCALE."
else
    echo "External display is not 4K. Setting scale to $EXTERNAL_SCALE."
fi
# Calculate logical width for the external display
LOGICAL_EXTERNAL_WIDTH=$(echo "scale=0; $EXTERNAL_PHY_WIDTH / $EXTERNAL_SCALE" | bc)


# Output detected and calculated values for user information
echo "Laptop: $LAPTOP_DISPLAY_NAME ($LAPTOP_RES, Scale: $LAPTOP_SCALE, Physical Width: $LAPTOP_PHY_WIDTH, Logical Width: $LOGICAL_LAPTOP_WIDTH)"
echo "External: $EXTERNAL_DISPLAY_NAME ($EXTERNAL_RES, Scale: $EXTERNAL_SCALE, Physical Width: $EXTERNAL_PHY_WIDTH, Logical Width: $LOGICAL_EXTERNAL_WIDTH)"

# --- Position Swapping Logic ---
# State file stores the current layout:
# 0 = External Left, Laptop Right
# 1 = Laptop Left, External Right
STATE_FILE="/tmp/hyprland_laptop_pos_state_dynamic"

# Initialize state if file doesn't exist (default to External Left, Laptop Right)
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

CURRENT_STATE=$(cat "$STATE_FILE")

if [ "$CURRENT_STATE" = "0" ]; then
    # Current: External is Left, Laptop is Right
    # Action:  Switch to Laptop Left, External Right
    echo "Switching to: Laptop ($LAPTOP_DISPLAY_NAME) LEFT, External ($EXTERNAL_DISPLAY_NAME) RIGHT"
    hyprctl --batch "\
        keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,0x0,$LAPTOP_SCALE;\
        keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,${LOGICAL_LAPTOP_WIDTH}x0,$EXTERNAL_SCALE"
    echo "1" > "$STATE_FILE" # Update state to: Laptop Left, External Right
else
    # Current: Laptop is Left, External is Right
    # Action:  Switch to External Left, Laptop Right
    echo "Switching to: External ($EXTERNAL_DISPLAY_NAME) LEFT, Laptop ($LAPTOP_DISPLAY_NAME) RIGHT"
    hyprctl --batch "\
        keyword monitor $EXTERNAL_DISPLAY_NAME,$EXTERNAL_RES,0x0,$EXTERNAL_SCALE;\
        keyword monitor $LAPTOP_DISPLAY_NAME,$LAPTOP_RES,${LOGICAL_EXTERNAL_WIDTH}x0,$LAPTOP_SCALE"
    echo "0" > "$STATE_FILE" # Update state to: External Left, Laptop Right
fi

echo "Monitor layout updated."
