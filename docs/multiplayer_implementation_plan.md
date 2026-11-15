# Multiplayer Implementation Plan

## Decision and scope

This plan targets the hackathon release for Windows, distributed as a direct `.exe` download. The selected integration is **GD-Sync**, subject to the proof-of-concept gate in Phase 0.

The release will support:

1. Local PvP on one PC using the existing horizontal split-screen presentation.
2. Online quick match with one random opponent.
3. Online friend play by creating or joining a private two-player room using a generated code.
4. A global event leaderboard for a common fixed seed and a simple online match-wins leaderboard.

The plan intentionally does not include accounts with email/password, platform friends, chat, voice, ranked matchmaking, anti-cheat, reconnects, spectators, or cross-platform support. The online game is a casual two-player race, not a cheat-resistant competitive service.

## Product decisions

| Area | Decision |
| --- | --- |
| Online transport | GD-Sync lobby relay and registered remote calls. Do not expose direct IP hosting to players. |
| Identity | Service-provided stable client ID plus a locally chosen, validated display name. |
| Friend join | A private lobby named with a random, human-readable code such as `ECHO-K7M9-PQ`. The code is the lobby identifier, not a short sequential number. |
| Quick match | Browse public open two-player lobbies matching the protocol tag. Join one at random, or create a new public lobby when none is available. Retry a join race once with a refreshed list. |
| Online presentation | One full-height local `PlayerWorld`; opponent status and progress appear in the HUD. Do not render a second remote camera. |
| Player slots | The lobby host is Player 1 and runs rightward. The joining player is Player 2 and runs leftward in a mirrored course. Each client controls only its own player with the Player 1 input actions. |
| Seed authority | The lobby host generates the course seed and sends it to the joining player. Both clients must acknowledge the same generator signature before the countdown begins. |
| Race clock | Each client renders its own timer. The host reconciles the finished result for the casual match result screen. |
| Disconnects | Before start: cancel the lobby. During a race: show that the opponent left and end the match. No reconnect or host migration in this release. |
| Leaderboards | Use a server-selected daily/event seed for comparable time trials. Track online match wins separately. Do not combine times from arbitrary random seeds. |

The host and clients are untrusted. GD-Sync relays data but does not make player physics or score submissions authoritative. The release must describe scoreboards as event/casual rankings and reject obvious invalid submissions, rather than claim anti-cheat protection.

## Phase 0: GD-Sync proof of concept

**Goal:** Prove that a Windows export can create and join a lobby from two external networks without port forwarding.

### Tasks

1. Create a GD-Sync project and review the current free-plan limits, platform support, terms, and dashboard controls.
2. Pin the tested plugin release in the repository and document its version.
3. Store service credentials outside version control. Verify which key is safe in a shipped client; never commit a dashboard or private credential. Add only a documented local configuration template to the repository.
4. Make a throwaway two-client test scene that:
   - connects both clients;
   - creates a private two-player lobby;
   - joins it by exact lobby name;
   - exchanges a typed test payload through an explicitly registered remote call;
   - reports a client leaving;
   - builds and runs as two Windows exports.
5. Repeat with two distinct internet connections, not merely two editor instances on one LAN.
6. Test public-lobby browsing, filtering tags, joining, and a deliberate simultaneous join collision.

### Exit criteria

- A generated room code works between two Windows machines on different networks.
- No secret required for dashboard administration appears in source control or the exported build.
- The plugin can relay the required messages with acceptable latency.
- Public lobby discovery supports the quick-match algorithm below.
- The tested free tier is sufficient for the hackathon audience.

If any exit criterion fails, stop before changing race gameplay. Re-evaluate EOS or self-hosted Nakama as a replacement service; do not combine multiple online backends in this release.

## Phase 1: session boundary and testable service adapter

**Goal:** Add an online abstraction without changing the existing local race behavior.

### New code boundaries

```text
scripts/online/
  online_service.gd             # Autoload interface and connection/lobby lifecycle.
  gd_sync_online_service.gd     # Only file that imports/calls GD-Sync APIs.
  online_match.gd               # Match lifecycle, protocol validation, race messages.
  online_protocol.gd            # Protocol constants and validated payload builders.
  local_match_service.gd        # Test double for SceneTree checks.
```

`OnlineService` exposes typed signals rather than GD-Sync signals to the rest of the game:

```gdscript
signal connected(client_id: int)
signal connection_failed(reason: String)
signal lobby_created(room_code: String)
signal lobby_joined(lobby: Dictionary)
signal lobby_join_failed(reason: String)
signal lobby_listed(lobbies: Array[Dictionary])
signal peer_joined(client_id: int)
signal peer_left(client_id: int)
signal message_received(sender_id: int, message: Dictionary)
```

The service owns connection, lobby creation, joining, browsing, leaving, and registered remote-call wiring. `Race`, `PlayerWorld`, and UI nodes must never invoke GD-Sync directly.

### Session and presentation refactor

Introduce a `RaceSession` configuration value, separate from scene node identity:

```gdscript
enum SessionMode {
    LOCAL,
    ONLINE,
}

enum PlayerSlot {
    PLAYER_ONE = 1,
    PLAYER_TWO = 2,
}
```

Refactor `PlayerWorld` setup so these concepts are independent:

- course direction and player colour come from the assigned player slot;
- input actions come from the local input controller;
- the world can be displayed in a split screen or full screen;
- only the local online player processes gameplay input.

Preserve `p1_left`, `p1_right`, `p1_jump`, and `p1_shout` through Godot's Input Map. Do not read physical keys or make a network mode depend on Player 2 arrow-key actions.

### Tests

- Existing local race shell tests continue to pass unchanged.
- A `LocalMatchService` test verifies state transitions without GD-Sync or an internet connection.
- Protocol tests reject missing fields, unknown message kinds, incorrect protocol versions, and messages from a peer outside the active lobby.

## Phase 2: private online friend rooms

**Goal:** Ship the lowest-risk playable online mode first.

### Room lifecycle

1. The creator connects and requests a random room code.
2. The creator makes a private lobby with `player_limit = 2`, protocol/build tags, and the room code as its unique name.
3. The creator joins the lobby promptly, then sees the room code and a waiting state.
4. The second player enters the exact code and joins the private lobby.
5. Players exchange `hello` messages containing protocol version, build version, display name, and assigned slot.
6. The host sends `race_setup` with course seed, slot assignment, and presentation values.
7. Each client generates its own course and replies with `course_ready`, including its deterministic course signature.
8. The host compares signatures. A mismatch shows a Polish version-mismatch error and returns both players to the online menu.
9. The host sends a start deadline three seconds ahead. Both clients enter the existing countdown then race.
10. Both clients exchange progress and lifecycle events until a result or disconnect.

### Required messages

All messages carry `protocol_version`, `match_id`, and a monotonically increasing sequence number where ordering matters.

| Kind | Sender | Payload | Purpose |
| --- | --- | --- | --- |
| `hello` | each peer | client ID, display name, build version | Confirm a compatible peer. |
| `race_setup` | host | seed, slots, start delay | Set the equivalent course. |
| `course_ready` | each peer | course signature | Verify seeded generation. |
| `race_start` | host | start deadline | Begin the shared countdown. |
| `player_status` | each peer | progress fraction, loudness, boost flag | Update opponent HUD at a capped rate. |
| `player_died` | each peer | elapsed time | Show optional opponent status. |
| `player_finished` | each peer | local finish event | Stop local timer and reconcile results. |
| `match_result` | host | both finish states, winner, reason | Present final result. |
| `rematch_vote` | each peer | accepted boolean | Start a new seed only after both votes. |

Only explicitly registered message handlers are callable remotely. Validate each payload's types, bounds, sender slot, and allowed state before changing gameplay state.

### Network rate and data limits

- Send `player_status` at 8–10 Hz, only while racing and only when the status changed enough to be useful.
- Send lifecycle messages reliably once and make them idempotent with a match ID and event identifier.
- Never send wave-ray state, terrain cells, particle state, raw input every physics frame, or full scene data.
- The local client runs all player physics, waves, echo feedback, collision, audio, and rendering.

### Friend-room acceptance tests

- Two exports join a private code from different networks.
- Both generate equal signatures for the received seed.
- Both see the countdown within an acceptable visual tolerance.
- A player finishing does not stop the opponent.
- A disconnect before start returns the other player to the online menu.
- A disconnect during a race ends it with a clear Polish message.
- A mismatched protocol/build cannot start a race.

## Phase 3: quick match

**Goal:** Match two random compatible players without a manual lobby browser.

### Algorithm

1. Request public lobbies.
2. Filter to open lobbies with one member, `player_limit = 2`, and tags for `mode = quick_race`, protocol version, and build version.
3. Randomize candidates and request a join.
4. If the join succeeds, continue with the Phase 2 handshake.
5. If every candidate is unavailable or no candidate exists, create a public quick-race lobby with the same tags.
6. On a join collision, refresh once and retry. Then show an actionable error or a wait/cancel state.
7. When the host sees a second player, mark the lobby unavailable for browsing and begin the compatibility handshake.

This is public-lobby discovery, not skill or region matchmaking. Add neither ratings nor queue persistence in the hackathon release.

### Acceptance tests

- Two queued clients pair without sharing a code.
- Incompatible protocol/build tags never appear as a candidate.
- Three clients do not produce a three-player match or leave a joined lobby incorrectly marked open.
- Cancelling while waiting leaves and removes the empty lobby.

## Phase 4: multiplayer UI and menu

**Goal:** Make all session paths visible and recoverable without keyboard-only hidden controls.

### Main menu

```text
REZONANS
WYŚCIG ECHA

[ GRA LOKALNA ]
[ GRA ONLINE ]
[ RANKING ]
[ USTAWIENIA ]
[ WYJDŹ ]
```

The online submenu contains:

```text
GRA ONLINE

[ SZYBKI MECZ ]
[ ZE ZNAJOMYM ]
[ POWRÓT ]
```

The friend submenu contains:

```text
ZE ZNAJOMYM

[ STWÓRZ POKÓJ ]
[ DOŁĄCZ KODEM ]
[ POWRÓT ]
```

Required Polish status/error views:

- `ŁĄCZENIE…`
- `SZUKANIE PRZECIWNIKA…`
- `POKÓJ: ECHO-K7M9-PQ`
- `CZEKA NA DRUGIEGO GRACZA…`
- `NIE UDAŁO SIĘ DOŁĄCZYĆ DO POKOJU.`
- `WERSJE GRY NIE SĄ ZGODNE.`
- `PRZECIWNIK OPUŚCIŁ MECZ.`

### Race presentation

- **Local:** retain two independent horizontal `SubViewport` worlds and current controls.
- **Online:** present only the local `PlayerWorld` full height. Display local and opponent names, timers/status, opponent progress, and connection state in the global HUD.
- Escape opens a local online pause menu with `WRÓĆ DO MECZU`, `OPUŚĆ MECZ`, and `MENU`. Leaving an online race requires confirmation.

### Results and rematch

- Local results retain Player 1 / Player 2 labels.
- Online results use player display names and distinguish a completed race from an opponent leave.
- Local rematch starts a new seed immediately after confirmation.
- Online rematch uses a mutual vote. A new seed and countdown begin only after both players accept; otherwise both return to the menu.

Implement menu navigation using Input Map actions added specifically for UI. Keep existing movement actions gameplay-only.

## Phase 5: leaderboards

**Goal:** Add scores that are understandable and reasonably resistant to trivial invalid submissions.

### Boards

1. **`DZISIEJSZA FALA`**: best completion times for the shared daily/event seed.
2. **`RANKING MECZÓW`**: online quick-match wins, completed races, and optional current streak.

Private friend matches do not affect match wins. Local games do not submit online scores.

### Daily/event time-trial flow

1. The service configuration provides an event ID, seed, protocol version, and start/end timestamps.
2. The client loads this configuration before launching the run.
3. The client must report the expected generator signature before a result is eligible.
4. Submit the result using the stable service identity, display name, event ID, seed, build/protocol version, and elapsed time.
5. Retain only the player's best event result.
6. Reject duplicate event submissions, wrong seeds/signatures, malformed data, and times below a conservative per-seed minimum.

A client can still be modified. Do not call the table secure or ranked until the project has server-side traversal validation or replay verification.

### UI

Add a `RANKING` screen with `DZISIEJSZA FALA` and `MECZE` tabs. After eligible results, the end screen displays a record or rank change without blocking rematch/menu actions.

## Phase 6: packaging, telemetry, and release readiness

1. Pin the GD-Sync plugin version and document dashboard setup and credential handling in a developer-only setup guide.
2. Verify that the Windows export includes required plugin dependencies but no secret/dashboard credentials.
3. Add an online feature flag and a clear offline error state so a service outage leaves local PvP playable.
4. Add privacy text for the display name, stable service ID, and leaderboard data. Keep telemetry off unless the team intentionally adds it.
5. Test on clean Windows machines, slow connections, and different networks.
6. Build a release checklist: plugin version, protocol version, event seed, leaderboard identifiers, and service dashboard availability.

## Delivery order

| Milestone | Deliverable | Depends on |
| --- | --- | --- |
| M0 | External-network GD-Sync proof of concept | GD-Sync account and test exports |
| M1 | Service adapter, protocol validation, unchanged local regression suite | M0 |
| M2 | Private friend room race from connection through results | M1 |
| M3 | Quick match | M2 |
| M4 | Online/local menu, race HUD, results, and rematch flows | M2; quick match UI can land after M3 |
| M5 | Daily/event leaderboard and match-wins board | M2 |
| M6 | Packaging and external playtest | M3–M5 |

The playable vertical slice is **M2**. If time is limited, ship local PvP, friend rooms, and the event leaderboard before quick match.

## Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| GD-Sync free-plan or export behavior is unsuitable | Online feature cannot ship | Resolve in M0 before race refactors. Keep all integration behind `OnlineService`. |
| Host leaves or crashes | The lobby loses its coordinator | Treat it as a match end in this release. Do not attempt host migration. |
| Two quick-match clients join the same room | One client receives a join failure | Refresh once, retry, then present an error/cancel choice. |
| Generator differs across builds | Players see incompatible courses | Tag lobbies by protocol/build and verify the generated course signature before race start. |
| Client-forged times | Leaderboards lose credibility | Limit boards to common seeds, submit only eligible results, use conservative time bounds, and label the feature casual/event. |
| Empty quick-match population | Players wait indefinitely | Always provide room-code play, a cancel action, and a visible waiting state. |
| Service outage | Game appears broken | Keep local mode fully independent and provide a clear online-unavailable state. |

## Definition of done

The feature is ready for the hackathon release when:

- Local PvP still runs with the existing independent split-screen worlds.
- Two clean Windows exports can complete a private online race over separate networks using a room code.
- Two compatible clients can complete a quick match without exchanging a code.
- No online race starts until both clients confirm the same course signature.
- Each online player controls only their own player and sees a full-height local world.
- Disconnects, cancellation, and incompatible versions return players to a usable UI state.
- The event leaderboard shows comparable fixed-seed results and online wins are tracked separately.
- Existing SceneTree checks and all new service/protocol tests pass.
- The exported build has no committed secrets and local PvP remains usable if the online service is unavailable.
