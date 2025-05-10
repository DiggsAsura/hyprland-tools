#!/usr/bin/env bash

# Description: This script dynamically swaps the active workspaces between two connected monitors in Hyprland.
# It detects the two monitors automatically. If exactly two monitors are not found,
# it will print an error message.
#
# Dependencies:
# - hyprctl (Hyprland's command-line utility)
# - jq (command-line JSON processor)

# Get monitor information in JSON format
monitor_json=$(hyprctl monitors -j)

# Count the number of monitors
monitor_count=$(echo "$monitor_json" | jq 'length')

if [ "$monitor_count" -eq 2 ]; then
  # Get the names of the two monitors
  monitor1=$(echo "$monitor_json" | jq -r '.[0].name')
  monitor2=$(echo "$monitor_json" | jq -r '.[1].name')

  if [ -n "$monitor1" ] && [ -n "$monitor2" ]; then
    # Swap active workspaces between the two monitors
    hyprctl dispatch swapactiveworkspaces "$monitor1" "$monitor2"
    echo "Byttet aktive arbeidsområder mellom $monitor1 og $monitor2." # User-facing message, kept in Norwegian as per original
  else
    echo "Feil: Kunne ikke hente navnene på en eller begge skjermene." # User-facing message
  fi
else
  echo "Feil: Dette scriptet er designet for nøyaktig to skjermer." # User-facing message
  echo "Antall skjermer funnet: $monitor_count" # User-facing message
  # Optional: List detected monitors for debugging
  # echo "Detected monitors:"
  # echo "$monitor_json" | jq -r '.[].name'
fi
