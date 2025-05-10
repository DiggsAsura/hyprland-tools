#!/bin/bash

# --- Script Description ---
# This script dynamically positions two displays (typically a laptop display and an
# external monitor) in Hyprland using absolute positioning flags.
# It attempts to auto-detect the laptop display (preferring "eDP" or "LVDS" names)
# and applies scaling independently (1.5x for 4K, 1x otherwise).
#
# --- Changelog ---
# v0.7 (2025-05-10):
#   - Dynamic detection of "Laptop" and "External" displays.
#     (Prefers "eDP"/"LVDS" names for laptop; falls back to hyprctl list order).
#   - Changed to direct positioning flags (not toggles), inspired by Vim keys:
#     -h: External display to the LEFT of Laptop display
#     -l: External display to the RIGHT of Laptop display
#     -k: External display ABOVE Laptop display
#     -j: External display BELOW Laptop display
#   - Removed state files; commands are now absolute positioning.
#   - Scaling logic (4K at 1.5x, others at 1x) applied independently to both displays.
#   - Script primarily targets 1 or 2 monitor setups for clarity.

# --- Dependencies ---
# - hyprctl: For interacting with the Hyprland compositor.
# - jq:      For parsing JSON output from hyprctl.
# - bc:      For performing floating-point arithmetic.

# --- Argument Parsing ---
MODE_ARG=""
if [ -n "$1" ]; then
    case "$1" in
        -h|-l|-k|-j)
            MODE_ARG="$1"
            ;;
        *)
            echo "Error: Invalid flag '$1'."
            ;;
    esac
else
    echo "Error: No positioning flag provided."
fi

if [ -z "$MODE_ARG" ]; then
    SCRIPT_NAME=$(basename "$0")
    echo "Usage: $SCRIPT_NAME [-h | -l | -k | -j]"
    echo "  -h: Place External display to the LEFT of Laptop display"
    echo "  -l: Place External display to the RIGHT of Laptop display"
    echo "  -k: Place External display ABOVE Laptop display"
    echo "  -j: Place External display BELOW Laptop display"
    exit 1
fi

# --- Tool Checks ---
for tool in jq bc hyprctl; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required command '$tool' not found. Please install it."
        exit 1
    fi
done

# --- Monitor Detection and Role Assignment ---
MONITORS_JSON=$(hyprctl monitors -j)
MONITOR_COUNT=$(echo "$MONITORS_JSON" | jq 'length')

LAPTOP_MONITOR_INFO=""
EXTERNAL_MONITOR_INFO=""
LAPTOP_DISPLAY_NAME_FOR_INFO="" # Used for messages

if [ "$MONITOR_COUNT" -eq 0 ]; then
    echo "Error: No monitors detected by Hyprland."
    exit 1
elif [ "$MONITOR_COUNT" -eq 1 ]; then
    echo "Info: Only one monitor detected. Configuring it as primary."
    LAPTOP_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[0]')
    EXTERNAL_MONITOR_INFO="" # No external monitor
    LAPTOP_DISPLAY_NAME_FOR_INFO=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.name')
elif [ "$MONITOR_COUNT" -ge 2 ]; then
    MON_1_INFO=$(echo "$MONITORS_JSON" | jq -c '.[0]')
    MON_2_INFO=$(echo "$MONITORS_JSON" | jq -c '.[1]') # Focus on the first two for clear roles
    MON_1_NAME_LOWER=$(echo "$MON_1_INFO" | jq -r '.name | ascii_downcase')
    MON_2_NAME_LOWER=$(echo "$MON_2_INFO" | jq -r '.name | ascii_downcase')

    # Heuristic: Prefer "eDP" or "LVDS" as laptop display
    if [[ "$MON_1_NAME_LOWER" == *"edp"* || "$MON_1_NAME_LOWER" == *"lvds"* ]]; then
        LAPTOP_MONITOR_INFO=$MON_1_INFO
        EXTERNAL_MONITOR_INFO=$MON_2_INFO
        echo "Info: Identified '$MON_1_NAME_LOWER' as Laptop display (eDP/LVDS match)."
    elif [[ "$MON_2_NAME_LOWER" == *"edp"* || "$MON_2_NAME_LOWER" == *"lvds"* ]]; then
        LAPTOP_MONITOR_INFO=$MON_2_INFO
        EXTERNAL_MONITOR_INFO=$MON_1_INFO
        echo "Info: Identified '$MON_2_NAME_LOWER' as Laptop display (eDP/LVDS match)."
    else
        # Fallback: Use hyprctl list order. First is "Laptop-proxy", second is "External-proxy".
        # Or, use focused as "Laptop-proxy"
        FOCUSED_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.focused == true)' | head -n 1) # head -n 1 in case of multiple focused (unlikely)
        NON_FOCUSED_MONITOR_INFO=$(echo "$MONITORS_JSON" | jq -c '.[] | select(.focused == false)' | head -n 1)

        if [ -n "$FOCUSED_MONITOR_INFO" ] && [ "$FOCUSED_MONITOR_INFO" != "null" ] && \
           [ -n "$NON_FOCUSED_MONITOR_INFO" ] && [ "$NON_FOCUSED_MONITOR_INFO" != "null" ]; then
            LAPTOP_MONITOR_INFO=$FOCUSED_MONITOR_INFO
            EXTERNAL_MONITOR_INFO=$NON_FOCUSED_MONITOR_INFO
            L_NAME_TEMP=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.name')
            E_NAME_TEMP=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.name')
            echo "Warning: No clear eDP/LVDS laptop display. Using focused ('$L_NAME_TEMP') as Laptop-proxy and non-focused ('$E_NAME_TEMP') as External-proxy."
        else # Fallback to list order if focus heuristic fails (e.g. all focused or none - unusual)
            LAPTOP_MONITOR_INFO=$MON_1_INFO
            EXTERNAL_MONITOR_INFO=$MON_2_INFO
            L_NAME_TEMP=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.name')
            E_NAME_TEMP=$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.name')
            echo "Warning: No clear eDP/LVDS laptop display & focus heuristic failed. Using first in list ('$L_NAME_TEMP') as Laptop-proxy and second ('$E_NAME_TEMP') as External-proxy."
        fi
    fi
    LAPTOP_DISPLAY_NAME_FOR_INFO=$(echo "$LAPTOP_MONITOR_INFO" | jq -r '.name')

    if [ "$MONITOR_COUNT" -gt 2 ]; then
        echo "Info: More than two monitors detected. Script will arrange identified Laptop display ('$LAPTOP_DISPLAY_NAME_FOR_INFO') and one External display ('$(echo "$EXTERNAL_MONITOR_INFO" | jq -r '.name')'). Other monitors are not managed by this script's positioning."
    fi
fi

# --- Helper Function to Process Monitor Info ---
# $1: Monitor JSON object
# Returns: "NAME|PHY_WIDTH|PHY_HEIGHT|REFRESH|RES|SCALE|LOGICAL_WIDTH|LOGICAL_HEIGHT"
get_monitor_details() {
    local mon_info=$1
    if [ -z "$mon_info" ] || [ "$mon_info" == "null" ]; then
        echo "|||||||" # Empty placeholders
        return
    fi

    local name phy_w phy_h refresh res scale log_w log_h
    name=$(echo "$mon_info" | jq -r '.name')
    phy_w=$(echo "$mon_info" | jq -r '.width')
    phy_h=$(echo "$mon_info" | jq -r '.height')
    refresh=$(echo "$mon_info" | jq -r '.refreshRate | tonumber | floor') # Get integer refresh rate

    res="${phy_w}x${phy_h}@${refresh}"

    # Determine scale (1.5 for 4K, else 1)
    if [ "$phy_w" -eq 3840 ] && [ "$phy_h" -eq 2160 ]; then
        scale="1.5"
    else
        scale="1"
    fi

    log_w=$(echo "scale=0; $phy_w / $scale" | bc)
    log_h=$(echo "scale=0; $phy_h / $scale" | bc)

    echo "$name|$phy_w|$phy_h|$refresh|$res|$scale|$log_w|$log_h"
}

# --- Process Laptop Monitor ---
IFS='|' read -r L_NAME L_PHY_W L_PHY_H L_REFRESH L_RES L_SCALE L_LOGICAL_W L_LOGICAL_H < <(get_monitor_details "$LAPTOP_MONITOR_INFO")

if [ -z "$L_NAME" ]; then
    echo "Error: Failed to process Laptop display details."
    exit 1
fi
echo "Laptop Display ('$L_NAME'): $L_RES, Scale: $L_SCALE, Logical: ${L_LOGICAL_W}x${L_LOGICAL_H}"

# --- Process External Monitor (if present) ---
E_NAME="" E_PHY_W="" E_PHY_H="" E_REFRESH="" E_RES="" E_SCALE="" E_LOGICAL_W="" E_LOGICAL_H=""
if [ -n "$EXTERNAL_MONITOR_INFO" ] && [ "$EXTERNAL_MONITOR_INFO" != "null" ]; then
    IFS='|' read -r E_NAME E_PHY_W E_PHY_H E_REFRESH E_RES E_SCALE E_LOGICAL_W E_LOGICAL_H < <(get_monitor_details "$EXTERNAL_MONITOR_INFO")
    if [ -z "$E_NAME" ]; then
        echo "Warning: Failed to process External display details, but it seemed present. Proceeding with Laptop only."
        EXTERNAL_MONITOR_INFO="" # Mark as not truly present for positioning
    else
        echo "External Display ('$E_NAME'): $E_RES, Scale: $E_SCALE, Logical: ${E_LOGICAL_W}x${E_LOGICAL_H}"
    fi
else
    echo "Info: No external display to position. Laptop display configured at 0x0."
    hyprctl keyword monitor "$L_NAME,$L_RES,0x0,$L_SCALE"
    echo "Monitor layout updated. Current date: $(date)"
    exit 0
fi


# --- Positioning Logic ---
HYPRCTL_BATCH_CMD=""

case "$MODE_ARG" in
    -h) # External Left of Laptop
        echo "Positioning: External ('$E_NAME') LEFT of Laptop ('$L_NAME')"
        HYPRCTL_BATCH_CMD="keyword monitor $E_NAME,$E_RES,0x0,$E_SCALE; keyword monitor $L_NAME,$L_RES,${E_LOGICAL_W}x0,$L_SCALE"
        ;;
    -l) # External Right of Laptop
        echo "Positioning: External ('$E_NAME') RIGHT of Laptop ('$L_NAME')"
        HYPRCTL_BATCH_CMD="keyword monitor $L_NAME,$L_RES,0x0,$L_SCALE; keyword monitor $E_NAME,$E_RES,${L_LOGICAL_W}x0,$E_SCALE"
        ;;
    -k) # External Top of Laptop
        echo "Positioning: External ('$E_NAME') TOP of Laptop ('$L_NAME')"
        HYPRCTL_BATCH_CMD="keyword monitor $E_NAME,$E_RES,0x0,$E_SCALE; keyword monitor $L_NAME,$L_RES,0x${E_LOGICAL_H},$L_SCALE"
        ;;
    -j) # External Bottom of Laptop
        echo "Positioning: External ('$E_NAME') BOTTOM of Laptop ('$L_NAME')"
        HYPRCTL_BATCH_CMD="keyword monitor $L_NAME,$L_RES,0x0,$L_SCALE; keyword monitor $E_NAME,$E_RES,0x${L_LOGICAL_H},$E_SCALE"
        ;;
esac

if [ -n "$HYPRCTL_BATCH_CMD" ]; then
    hyprctl --batch "$HYPRCTL_BATCH_CMD"
    echo "Monitor layout updated. Current date: $(date)"
else
    echo "Error: No valid positioning command generated. This should not happen if a flag was parsed."
    exit 1
fi
