# Automatic tuned-adm Profile Switching based on Power/Battery using systemd

This guide describes how to set up a Linux system (tested on openSUSE with Hyprland) to automatically switch `tuned-adm` profiles based on whether the laptop is connected to AC power (docked) or running on battery, as well as the current battery level. The solution uses a shell script along with systemd timer and service units.

## Goal

* Use a specific `tuned-adm` profile when the machine is connected to AC power.
* Use a balanced `tuned-adm` profile when on battery with sufficient charge (e.g., > 30%).
* Use a power-saving `tuned-adm` profile when on battery with low charge (e.g., < 30%).
* Use a power-saving `tuned-adm` profile when the battery level is critical (e.g., < 10%).

## Prerequisites

* `tuned-adm` installed and configured.
* A system using `systemd` (standard on most modern Linux distributions like openSUSE, Fedora, Ubuntu, etc.).
* Access to `sudo` or root privileges.

## Step 1: The Logic and Switching Script

This script checks the power status and battery level, then calls `tuned-adm` to set the appropriate profile.

1.  **Create the file:** `/usr/local/bin/update-tuned-profile.sh`
2.  **Paste the following content** (customize paths and profiles under "Configuration"):

    ```bash
    #!/bin/bash

    # --- Configuration ---
    # Adjust BATTERY_PATH if necessary (usually BAT0 or BAT1)
    # Find yours with e.g., 'ls /sys/class/power_supply/'
    BATTERY_PATH="/sys/class/power_supply/BAT0"
    # Percentage for critical level
    CRITICAL_LEVEL=10

    # Profiles to use (choose from 'tuned-adm list')
    PROFILE_AC="latency-performance"      # Profile when on AC power
    PROFILE_BAT_HIGH="balanced-battery"   # Profile on battery > 30%
    PROFILE_BAT_LOW="powersave"           # Profile on battery < 30%
    PROFILE_BAT_CRITICAL="powersave"      # Profile on battery < CRITICAL_LEVEL
    # --- End Configuration ---

    # Function to set profile if it's not already active
    set_tuned_profile() {
        local new_profile="$1"
        # Get current profile, remove leading/trailing whitespace
        local current_profile=$(tuned-adm active | grep 'Current active profile:' | cut -d ':' -f 2 | xargs)

        if [ "$current_profile" != "$new_profile" ]; then
            echo "Switching to tuned profile: $new_profile (Was: $current_profile)"
            # Using sudo here is unnecessary if the script is run by the root systemd service.
            tuned-adm profile "$new_profile"
        else
            # Avoid unnecessary log spam if profile is already correct
            # echo "Tuned profile '$current_profile' is already active."
            : # Do nothing
        fi
    }

    # Check if the battery sysfs path exists
    if [ ! -d "$BATTERY_PATH" ]; then
        echo "ERROR: Battery not found at $BATTERY_PATH" >&2
        # Fallback: Check AC directly if battery path doesn't exist
        # Check all AC* devices; returns 0 if any file contains '1'
        if grep -q 1 /sys/class/power_supply/AC*/online 2>/dev/null; then
             echo "Battery path not found, but AC power detected."
             set_tuned_profile "$PROFILE_AC"
        else
             echo "Battery path not found, and not on AC power. Not setting profile." >&2
        fi
        exit 1
    fi

    # Get battery status and capacity
    BAT_STATUS=$(cat "$BATTERY_PATH/status")
    BAT_CAPACITY=$(cat "$BATTERY_PATH/capacity")

    # Check if we are on AC power (docked/charging)
    IS_ON_AC=0
    # Checks all AC* devices; sets IS_ON_AC=1 if at least one is online ('1')
    if grep -q 1 /sys/class/power_supply/AC*/online 2>/dev/null; then
        IS_ON_AC=1
    fi

    # Determine which profile to use
    if [ "$IS_ON_AC" -eq 1 ]; then
        # On AC Power
        set_tuned_profile "$PROFILE_AC"
    else
        # On Battery
        if [ "$BAT_CAPACITY" -le "$CRITICAL_LEVEL" ]; then
            set_tuned_profile "$PROFILE_BAT_CRITICAL"
        elif [ "$BAT_CAPACITY" -lt 30 ]; then
            set_tuned_profile "$PROFILE_BAT_LOW"
        else # >= 30%
            set_tuned_profile "$PROFILE_BAT_HIGH"
        fi
    fi

    exit 0
    ```

3.  **Make the script executable:**
    ```bash
    sudo chmod +x /usr/local/bin/update-tuned-profile.sh
    ```

## Step 2: Systemd Service Unit

This unit tells systemd *how* to run the script. It's run as root because `tuned-adm` requires it.

1.  **Create the file:** `/etc/systemd/system/tuned-profile-updater.service`
2.  **Paste content:**
    ```ini
    [Unit]
    Description=Update tuned-adm profile based on power status

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/update-tuned-profile.sh
    # Run as root to have permission for tuned-adm
    User=root

    # No [Install] section needed as it's started by the timer
    ```

## Step 3: Systemd Timer Unit

This unit tells systemd *when* to run the service (and thus the script).

1.  **Create the file:** `/etc/systemd/system/tuned-profile-updater.timer`
2.  **Paste content:**
    ```ini
    [Unit]
    Description=Run tuned-profile-updater periodically

    [Timer]
    # Run 1 minute after boot
    OnBootSec=1min
    # Run every 2 minutes after the last run finished
    # (Alternative: OnUnitActiveSec=2min to run 2 mins after start)
    OnUnitInactiveSec=2min
    # Allow some leeway to save power by batching timers
    AccuracySec=30s

    [Install]
    WantedBy=timers.target
    ```

## Step 4: Activation and Management (Systemd Commands)

Use these commands to make systemd aware of the new files, enable the timer, and check its status.

1.  **Reload systemd manager configuration:** (Run after creating/editing unit files)
    ```bash
    sudo systemctl daemon-reload
    ```
2.  **Enable the timer (to start automatically on boot):**
    ```bash
    sudo systemctl enable tuned-profile-updater.timer
    ```
3.  **Start the timer manually for the first time (or after changes):**
    ```bash
    sudo systemctl start tuned-profile-updater.timer
    ```
4.  **Check the timer status:** (Should show `active (waiting)`)
    ```bash
    systemctl status tuned-profile-updater.timer
    ```
5.  **Check the status of the last service (script) execution:** (Should show `inactive (dead)` and `status=0/SUCCESS`)
    ```bash
    systemctl status tuned-profile-updater.service
    ```
6.  **View the script's log/output:** (Useful for debugging)
    ```bash
    journalctl -u tuned-profile-updater.service
    ```
7.  **Check the currently active `tuned-adm` profile:**
    ```bash
    tuned-adm active
    ```

## Customization

* Modify profile names (`PROFILE_*`), battery path (`BATTERY_PATH`), and thresholds (`CRITICAL_LEVEL`, `30`%) in `/usr/local/bin/update-tuned-profile.sh`.
* Adjust the run interval (e.g., `OnUnitInactiveSec=5min`) in `/etc/systemd/system/tuned-profile-updater.timer`. Remember to run `sudo systemctl daemon-reload` and `sudo systemctl restart tuned-profile-updater.timer` after modifying the timer file.

## Troubleshooting

If things don't work as expected:
* Use the `systemctl status ...` commands above to check for errors in the timer or service units.
* Use `sudo journalctl -xe` immediately after a failed start attempt to see detailed systemd logs.
* Use `journalctl -u tuned-profile-updater.service` to check the script's output for errors or logic issues.
* Double-check the script and unit files for typos or syntax errors.
* Verify the `BATTERY_PATH` in the script is correct for your system.
* Ensure the `tuned-adm` profile names used in the script exist (`tuned-adm list`).
