# How Vigil works

## Layout

| Path | What |
|---|---|
| `Sources/VigilCore` | All logic, no UI. Testable with fakes. |
| `Sources/Vigil` | SwiftUI menu bar app, thin. |
| `Tests/VigilCoreTests` | Time parsing, battery/heat rules, the session state machine. |
| `scripts/` | App bundling, opt-in lid helper, backstop, icon rendering. |

## A session

`SessionController` is a small state machine: `idle` or `running(endsAt, lidMode)`.

1. `start(duration:lidMode:)` checks the duration (1 minute to 7 days) and refuses a second session.
2. Standard mode takes an IOKit assertion (`PreventUserIdleSystemSleep`). No child process, and the
   kernel releases it if Vigil dies.
3. A ticker calls `tick()` every 5 seconds. A tick ends the session when time is up or when
   `FloorRules` says so.
4. `stop()` releases the assertion and, in lid mode, switches lid mode off.

The countdown in the UI is drawn from `endsAt`, so it never drifts.

## Floors

`FloorRules.evaluate` is a pure function over a `PowerSnapshot`:

- Battery below 10% while discharging ends the session. Plugged in, the rule is ignored.
- Critical thermal state always ends it. Serious thermal state ends it in lid mode.

## Lid mode and why it is careful

Staying awake with the lid closed needs `pmset -a disablesleep 1`, which needs root. The risk is
not turning it on, it is failing to turn it off. So:

1. **Opt-in privilege.** `scripts/install-lid-helper.sh` adds a sudoers rule for exactly
   `pmset -a disablesleep 1` and `... 0`. Without it, lid mode is disabled in the UI.
2. **Journal first.** Before enabling, Vigil writes `~/Library/Application Support/Vigil/journal.json`
   (mode 0600). It is removed only after sleep is restored.
3. **Recovery at launch.** If a journal is left over, the next launch restores sleep.
4. **Backstop agent.** A LaunchAgent runs `backstop.sh` every 60 seconds. If the journal says lid
   mode is on and either Vigil is not running or the session is more than two minutes overdue, it
   turns lid mode off.
5. **Failure is loud.** If restoring fails, the journal stays, the menu bar shows a warning icon,
   and the app prints the command to run by hand.

## Known limits

- The sudoers rule is not exclusive to Vigil; any process running as your user can use it.
- The backstop script and plist live in your home directory, so a process running as you can edit them.
- Floors and the ticker only run while the app runs. The backstop only handles the app dying, not heat.
- Builds are ad-hoc signed and not notarized.
- Lid mode has not been validated on every Mac model. Test with a short session you can watch.

## Tests

`swift test` runs 19 tests. They cover duration parsing, the battery and heat rules, and the controller
with fake power, lid and assertion ports: failed enable, failed assertion, failed restore, and
recovery of a leftover journal. They do not touch real power settings.
