#!/bin/bash
# Removes the sudoers rule and backstop agent, and makes sure sleep is back to normal.
set -u
LABEL="com.juansuarezdev.nonsleep.backstop"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/Library/Application Support/NonSleep/backstop.sh"
sudo /usr/bin/pmset -a disablesleep 0
rm -f "$HOME/Library/Application Support/NonSleep/journal.json"
sudo rm -f /etc/sudoers.d/non-sleep
echo "Removed. Sleep restored."
