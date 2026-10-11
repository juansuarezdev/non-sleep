#!/bin/bash
# Removes the sudoers rule and backstop agent, and makes sure sleep is back to normal.
set -u
LABEL="com.juansuarezdev.vigil.backstop"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/Library/Application Support/Vigil/backstop.sh"
sudo /usr/bin/pmset -a disablesleep 0
rm -f "$HOME/Library/Application Support/Vigil/journal.json"
sudo rm -f /etc/sudoers.d/vigil
echo "Removed. Sleep restored."
