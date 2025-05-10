# Hyprland-tools

A collection of tools for Hyprland, a dynamic tiling Wayland compositor. This repository includes scripts and utilities to enhance your Hyprland experience. At least my own :) Feel free to use at your own risk.



# Hyprland Display Positioner (v0.7)

This script dynamically positions your laptop display and an external monitor in Hyprland using simple, Vim-key inspired commands. It attempts to automatically identify your laptop display and applies appropriate scaling (e.g., 1.5x for 4K displays).

## Features

* **Dynamic Display Detection:** Automatically attempts to identify "Laptop" and "External" displays. Prefers names like "eDP-1" or "LVDS-1" for the laptop display.
* **Absolute Positioning:** Uses single flags to set a specific layout:
    * `-h`: External display to the LEFT of Laptop
    * `-l`: External display to the RIGHT of Laptop
    * `-k`: External display ABOVE Laptop
    * `-j`: External display BELOW Laptop
* **Smart Scaling:** Applies 1.5x scale to any 4K (3840x2160) display, and 1x to others, independently for each monitor.
* **Focus on 2-Monitor Setups:** Designed primarily for arranging one laptop and one external display. Also handles single-monitor setups gracefully.

## Prerequisites

Ensure you have the following installed:
* `hyprctl` (comes with Hyprland)
* `jq` (JSON processor)
* `bc` (basic calculator utility)

You can usually install `jq` and `bc` via your system's package manager (e.g., `sudo apt install jq bc` or `sudo pacman -S jq bc`).

## Setup

1.  **Save the Script:** Save the script content to a file, for example, `~/scripts/hypr_display_positioner.sh`.
2.  **Make it Executable:**
    ```bash
    chmod +x ~/scripts/hypr_display_positioner.sh
    ```
    *The script attempts to auto-detect your displays, so manual configuration of display names within the script is typically not required for common setups.*

## Usage

Run the script from your terminal with one of the positioning flags:

* **External Left of Laptop:**
    `~/scripts/toggle_laptop-position_v0.7.sh -h`
* **External Right of Laptop:**
    `~/scripts/toggle_laptop-position_v0.7.sh -l`
* **External Above Laptop:**
    `~/scripts/toggle_laptop-position_v0.7.sh -k`
* **External Below Laptop:**
    `~/scripts/toggle_laptop-position_v0.7.sh -j`

If run without a flag, or with an invalid flag, the script will display usage instructions.

## Example Hyprland Keybindings

Add these to your `~/.config/hypr/hyprland.conf` (adjust script path and keybindings as needed):

```ini
# Path to your script
$DISPLAY_SCRIPT = ~/scripts/toggle_laptop_position-v0.7.sh

# Place External display to the LEFT of Laptop
bind = $mod ALT, H, exec, $DISPLAY_SCRIPT -h

# Place External display to the RIGHT of Laptop
bind = $mod ALT, L, exec, $DISPLAY_SCRIPT -l

# Place External display ABOVE Laptop
bind = $mod ALT, K, exec, $DISPLAY_SCRIPT -k

# Place External display BELOW Laptop
bind = $mod ALT, J, exec, $DISPLAY_SCRIPT -j
``` 


***





## Hyprland Dynamic Workspace Swapper

This script dynamically swaps the active workspaces between two connected monitors in Hyprland. It automatically detects the names of the two monitors, making it a seamless experience if you frequently switch which workspace is on which screen.

### Purpose

The primary goal of this script is to provide a dynamic way to execute Hyprland's `swapactiveworkspaces` dispatcher without needing to hardcode monitor names. This is particularly useful for setups where monitor identifiers might change or for users who prefer a more automated approach.

### Dependencies

Before using this script, ensure you have the following installed:

* **Hyprland:** The Wayland compositor this script is designed for.
* **`hyprctl`:** The command-line utility for Hyprland (comes with Hyprland).
* **`jq`:** A lightweight and flexible command-line JSON processor. You can typically install it using your system's package manager (e.g., `sudo apt install jq`, `sudo pacman -S jq`, `brew install jq`).

### Usage

1.  **Download the Script:**
    Save the script (e.g., as `swap_workspaces.sh`) to a directory on your system (e.g., `~/.config/hypr/scripts/`).

2.  **Make it Executable:**
    Open your terminal and navigate to the directory where you saved the script, then run:
    ```bash
    chmod +x swap_workspaces.sh
    ```

3.  **Run the Script:**
    You can execute the script directly from your terminal:
    ```bash
    /path/to/your/swap_workspaces.sh
    ```
    (Replace `/path/to/your/` with the actual path to the script).

4.  **Integrate with Hyprland (Recommended):**
    For convenient use, bind the script to a hotkey in your `hyprland.conf` file (usually located at `~/.config/hypr/hyprland.conf`). Add a line similar to this:
    ```ini
    bind = $mainMod, S, exec, /path/to/your/swap_workspaces.sh
    ```
    Replace `$mainMod` with your preferred modifier key (e.g., `SUPER` for the Windows/Command key) and `S` with your desired key. Remember to use the correct path to your script. Reload your Hyprland configuration after making changes.

### How it Works

The script uses `hyprctl monitors -j` to get a JSON output of all connected monitors. It then uses `jq` to count the monitors and extract their names. If exactly two monitors are detected, it constructs and executes the `hyprctl dispatch swapactiveworkspaces MONITOR1 MONITOR2` command. If a different number of monitors is found, it will output an error message.
