#!/bin/bash
# Opt-in setup for Non-Sleep's lid-closed mode. Run it yourself; it asks for your password once (sudo).
# Installs:
#   1. /etc/sudoers.d/non-sleep     lets YOUR USER run exactly two commands without a password:
#                                 /usr/bin/pmset -a disablesleep 1
#                                 /usr/bin/pmset -a disablesleep 0
#                               Any program running as you can use this rule, not only Non-Sleep.
#   2. A LaunchAgent that runs backstop.sh every minute and undoes lid mode if the app died.
# Undo everything with scripts/uninstall-lid-helper.sh.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT="$HOME/Library/Application Support/NonSleep"
PLIST="$HOME/Library/LaunchAgents/com.juansuarezdev.nonsleep.backstop.plist"
LABEL="com.juansuarezdev.nonsleep.backstop"
RULE=/etc/sudoers.d/non-sleep

[[ "$(id -u)" != 0 ]] || { echo "Run as your normal user, not root."; exit 1; }

echo "This will add a sudoers rule for exactly these two commands, for user '$USER':"
echo "  /usr/bin/pmset -a disablesleep 1"
echo "  /usr/bin/pmset -a disablesleep 0"
read -r -p "Continue? [y/N] " answer
[[ "$answer" == [yY] ]] || { echo "Nothing changed."; exit 0; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<RULES
$USER ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
$USER ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
RULES
sudo /usr/sbin/visudo -cf "$tmp" >/dev/null || { echo "sudoers validation failed. Nothing changed."; exit 1; }
sudo /usr/bin/install -m 0440 -o root -g wheel "$tmp" "$RULE"
echo "sudoers rule installed."

mkdir -p "$SUPPORT" "$(dirname "$PLIST")"
chmod 700 "$SUPPORT"
install -m 0700 "$SRC/backstop.sh" "$SUPPORT/backstop.sh"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$SUPPORT/backstop.sh</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
</dict></plist>
PLISTEOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Backstop agent loaded. Lid mode is now available in Non-Sleep."
