# Online Race Presentation

Online races use one full-height local world. The top-left HUD displays the local session name, opponent session name, both timers, and the opponent's reported progress, loudness, and active rebound boost. The top-right status reads `POŁĄCZONO` after a match configures.

The current names are session pseudonyms in the form `ECHO-1234`, generated from the GD-Sync client ID. A player-editable persistent profile name is deferred until the settings screen is added.

The local client sends a compact `player_status` message at 10 Hz while racing. It contains only normalized progress, loudness, and boost state. It does not transmit input frames, terrain, wave rays, physics, particles, or audio state.

After an online result, the result panel offers:

```text
ENTER  REWANŻ        ESC  MENU
```

A rematch begins only after both racers accept. The host then selects a new seed and repeats course-signature validation before the countdown. Escape leaves the current lobby and restores the local main menu.

The corresponding unit check verifies opponent status, result handling, and mutual rematch setup in `tests/online_match_check.gd`.
