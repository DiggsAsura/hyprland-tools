# Hyprland-tools

A collection of tools for Hyprland, a dynamic tiling Wayland compositor. This repository includes scripts and utilities to enhance your Hyprland experience. At least my own :) Feel free to use at your own risk.



## Hyprland Dynamic Display Layout Toggler

This script provides a flexible way to manage and toggle the layout of a laptop's internal display and a single connected external monitor in a Hyprland environment. It supports both horizontal (side-by-side) and vertical (stacked) arrangements, automatically handling scaling for 4K displays and ensuring correct mouse cursor passthrough.

### Features

* **Dynamic Layout Toggling:**
    * Toggle between the laptop display being on the left/right of the external display.
    * Toggle between the laptop display being on the top/bottom of the external display.
* **Automatic Monitor Detection:** Automatically identifies the connected external monitor and its properties (resolution, refresh rate).
* **Smart 4K Scaling:** Applies a `1.5x` scale factor to the external monitor if it's detected as 4K (3840x2160). Other resolutions use `1x` scale. The laptop display is always set to `1x` scale.
* **Correct Mouse Passthrough:** Calculates and uses logical (scaled) monitor dimensions to ensure seamless mouse movement between displays.
* **Stateful Toggling:** Remembers the last layout for each mode (horizontal/vertical) and switches to the other available option within that mode.

### Prerequisites

Ensure the following utilities are installed on your system:
* `hyprctl` (part of Hyprland)
* `jq` (command-line JSON processor)
* `bc` (basic calculator for arithmetic)

You can typically install `jq` and `bc` using your system's package manager (e.g., `sudo apt install jq bc` or `sudo pacman -S jq bc`).

### Configuration

1.  **Script Name:** Save the script to a convenient location, for example, `~/scripts/hyprland-tools/hypr_display_toggle.sh`.
2.  **Make it Executable:**
    ```bash
    chmod +x ~/scripts/hyprland-tools/hypr_display_toggle.sh
    ```
3.  **Set Laptop Display Name:**
    Open the script file and locate the `User Configuration` section. Modify the `LAPTOP_DISPLAY_NAME` variable to match your laptop's internal display identifier.
    ```bash
    # --- User Configuration ---
    # Important: Set your laptop's internal display name here.
    # You can find your display name by running `hyprctl monitors` in a terminal.
    LAPTOP_DISPLAY_NAME="eDP-1" # Change "eDP-1" if yours is different
    ```
    You can find your display's name by running `hyprctl monitors` in a terminal. Common names include `eDP-1`, `LVDS-1`, etc.

### Usage

Run the script from your terminal with one of the following flags:

* **Toggle Horizontal Layout:**
    ```bash
    ~/scripts/hyprland-tools/hypr_display_toggle.sh -h
    ```
    This will switch the side-by-side arrangement (e.g., if the external monitor is on the left and laptop on the right, it will switch to laptop on the left and external on the right, and vice-versa).

* **Toggle Vertical Layout:**
    ```bash
    ~/scripts/hyprland-tools/hypr_display_toggle.sh -v
    ```
    This will switch the stacked arrangement (e.g., if the external monitor is on top and laptop on the bottom, it will switch to laptop on top and external on the bottom, and vice-versa).

### Example Hyprland Keybindings

Add the following to your `~/.config/hypr/hyprland.conf` file to bind these actions to keys. Remember to adjust the path to the script if yours is different.

```ini
# Define your script path (optional, but can make binds cleaner)
$SCRIPT = ~/scripts/hyprland-tools/hypr_display_toggle.sh

# Example keybindings
# Replace $mod, P and $mod, SHIFT, P with your preferred key combinations

# Toggle horizontal layout (e.g., External Left/Right of Laptop)
bind = $mod, P, exec, $SCRIPT -h

# Toggle vertical layout (e.g., External Top/Bottom of Laptop)
bind = $mod, SHIFT, P, exec, $SCRIPT -v
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
