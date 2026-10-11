#!/bin/bash
# Vigil backstop. Run every 60s by a LaunchAgent. If lid mode could still be on with nobody
# in charge of turning it off (app gone, or session overdue), turn it off and clear the journal.
set -u
SUPPORT="$HOME/Library/Application Support/Vigil"
JOURNAL="$SUPPORT/journal.json"
LOG="$HOME/Library/Logs/Vigil/backstop.log"
GRACE=120   # seconds past endsAt before we step in while the app is still running
umask 077
mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >> "$LOG"; }

[[ -f "$JOURNAL" ]] || exit 0
[[ "$(/usr/bin/plutil -extract lidModeEnabled raw -o - "$JOURNAL" 2>/dev/null)" == "true" ]] || exit 0

ends_raw="$(/usr/bin/plutil -extract endsAt raw -o - "$JOURNAL" 2>/dev/null)"
ends="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$ends_raw" +%s 2>/dev/null || echo 0)"
now="$(/bin/date +%s)"

reason=""
/usr/bin/pgrep -x Vigil >/dev/null || reason="app not running"
(( now > ends + GRACE )) && reason="${reason:-session overdue}"
[[ -n "$reason" ]] || exit 0

if /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0; then
  rm -f "$JOURNAL"
  log "restored sleep ($reason)"
else
  log "ERROR could not restore sleep ($reason); run: sudo pmset -a disablesleep 0"
  exit 1
fi
