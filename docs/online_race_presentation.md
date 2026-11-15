# Online Race Presentation

Online races retain the horizontal split-screen presentation from local play. The top viewport displays the local player (`TY`), and the bottom viewport displays the remote opponent (`PRZECIWNIK`) running on the same course seed without course mirroring. The top-left HUD displays both player names, timers, and the opponent's reported progress, loudness, and active rebound boost. The top-right status reads `POŁĄCZONO` after a match configures.

The current names are session pseudonyms in the form `ECHO-1234`, generated from the GD-Sync client ID. A player-editable persistent profile name is deferred until the settings screen is added.

The local client sends a spatial `player_status` message at 20 Hz while racing. It contains normalized progress, loudness, boost state, global position, velocity, facing direction, and discrete gameplay event triggers (such as shouts, footsteps, jumps, landings, and fall resets). The receiving client renders the remote opponent as an interpolated puppet in the second viewport and instances remote sound waves and reveal rings locally on identical course terrain.

After an online result, the result panel offers:

```text
ENTER  REWANŻ        ESC  MENU
```

A rematch begins only after both racers accept. The host then selects a new seed and repeats course-signature validation before the countdown. Escape leaves the current lobby and restores the local main menu.

The corresponding unit checks verify opponent status, snapshot replication, result handling, and mutual rematch setup in `tests/online_match_check.gd`.
