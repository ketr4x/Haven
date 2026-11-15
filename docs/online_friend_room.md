# Private Online Friend Rooms

The game now has an online race session behind the GD-Sync `OnlineService` boundary. This is the first playable online flow; main-menu controls will replace its command-line entry points in the menu phase.

## Run an online race

Build a Windows export with the local GD-Sync key file configured, then use PowerShell in the export directory.

The host may choose a code:

```powershell
.\Rezonans.exe -- --online-host=ECHO-K7M9
```

Or generate one automatically:

```powershell
.\Rezonans.exe -- --online-host
```

The joining player runs:

```powershell
.\Rezonans.exe -- --online-join=ECHO-K7M9
```

Arguments must follow the standalone `--`, which separates Godot engine arguments from Rezonans arguments.

## Session behavior

1. The host creates and joins a private two-player GD-Sync lobby.
2. The guest joins using the exact room code.
3. The host selects a random course seed and receives Player 1's rightward, pink course.
4. The guest receives Player 2's leftward, blue mirrored course.
5. Each client generates its own course and returns the generator signature.
6. The race begins only when the host has matching signatures from both clients.
7. Each client renders one full-height local world and uses the existing Player 1 controls: `A`/`D` to move, `W` to jump, and `S` to shout.
8. A finish event freezes the local player but leaves the other racer active. When both finishes arrive, the host sends the result to both clients.
9. If either player leaves before completion, the other client receives an opponent-left result.

The current HUD still uses temporary Player 1/Player 2 labels. The dedicated online menus, player display names, opponent-progress HUD, rematch vote, and end-screen redesign are later phases.

## Scope and integrity

The session validates protocol versions, room codes, message shapes, course signatures, countdown duration, slots, and finish-result payloads. Player simulation remains local, and the host accepts client-reported finish times. It is therefore suitable for casual hackathon races but not a cheat-resistant ranked mode.

## Tests

- `tests/online_match_check.gd` simulates a host room with `LocalMatchService` and verifies seed setup, matching course signatures, countdown, finishes, and the final winner.
- `tests/online_service_check.gd` verifies the service boundary and protocol validation without internet access.
- `scenes/game/gd_sync_poc.tscn` remains the manual external-network relay check.
