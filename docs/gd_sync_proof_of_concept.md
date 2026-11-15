# GD-Sync Proof of Concept

## Purpose

This proof of concept verifies the smallest online path required by Rezonans before the race scene, player movement, menu, or leaderboard code is changed:

- managed GD-Sync connection;
- private two-player lobby creation and exact-name join;
- public lobby browsing;
- an explicitly exposed remote function between peers;
- Windows export packaging;
- isolation from the local PvP scene and its SceneTree checks.

It is not gameplay code and must not be used as the multiplayer architecture. The later `OnlineService` adapter will encapsulate GD-Sync.

## Pinned dependency

The plugin source lives at `addons/GD-Sync/` and is pinned to:

- upstream repository: `https://github.com/GD-Sync/GD-Sync.git`
- upstream commit: `ba7f8e4068f6afb4b72e7b864a1e0c0c4e1069c2`
- plugin version: `1.0.2`

The upstream license is retained in `addons/GD-Sync/LICENSE`.

The proof scene creates the `MultiplayerClient` only while it is running. Do not register it as a project-wide autoload yet. A global GD-Sync autoload initializes before SceneTree test scenes exist and produces startup errors in the existing local regression checks.

## Credentials

GD-Sync requires a project-specific public/private API key pair. Create a dedicated Rezonans test key in the GD-Sync dashboard. Do not use an account, dashboard, or other administrative credential.

Store the pair locally at `addons/GD-Sync/keys.cfg`:

```ini
[keys]
publicKey = "replace-with-public-key"
privateKey = "replace-with-private-key"
```

The file is ignored by Git. It must never be committed, copied into documentation, or printed to logs.

GD-Sync's export plugin embeds this project key pair in the exported client. The proof does not treat the `privateKey` as a confidential server-side secret. Use a key scoped only to this game and rotate it if an exported build is compromised. Do not place any credential capable of administering the GD-Sync dashboard in the project.

## Running the proof scene

The commands below use the repository script, which finds the Windows Godot editor from WSL. Run a host first. It displays and logs the room code.

```bash
./scripts/run_godot.sh --scene res://scenes/game/gd_sync_poc.tscn -- \
  --poc-mode=host
```

Run the joining client on a separate machine/network, substituting the host's code:

```bash
./scripts/run_godot.sh --scene res://scenes/game/gd_sync_poc.tscn -- \
  --poc-mode=join --poc-room=ECHO-K7M9
```

Run a public host before browse mode to verify public discovery:

```bash
./scripts/run_godot.sh --scene res://scenes/game/gd_sync_poc.tscn -- \
  --poc-mode=host --poc-room=ECHO-K7M9 --poc-public=true
```

Use browse mode to verify public lobby discovery:

```bash
./scripts/run_godot.sh --scene res://scenes/game/gd_sync_poc.tscn -- \
  --poc-mode=browse
```

For unattended validation, add `--poc-quit-after=12`. Add `--poc-leave-after=3` on the joining client to leave three seconds after the client has actually joined, then verify whether the host receives a leave event before either process exits. The scene logs events with the `GD_SYNC_POC` prefix. It never logs credentials.

Expected host/join events include:

```text
GD_SYNC_POC connected
GD_SYNC_POC lobby_created=ECHO-K7M9
GD_SYNC_POC lobby_joined=ECHO-K7M9
GD_SYNC_POC peer_joined=<client-id>
GD_SYNC_POC probe_received_from=<client-id> payload=echo-poc
GD_SYNC_POC probe_received_from=<client-id> payload=echo-ack
```

## Export verification

The normal Windows export includes the proof scene and the GD-Sync source. To temporarily export the proof as the main scene, change only `run/main_scene` locally to `res://scenes/game/gd_sync_poc.tscn`, build with `./scripts/build_windows.sh`, and restore `project.godot` before committing.

The resulting `Rezonans.exe` can be launched with:

```text
Rezonans.exe --poc-mode=host
Rezonans.exe --poc-mode=join --poc-room=ECHO-K7M9
Rezonans.exe --poc-mode=browse
```

Build output is ignored. Test the exported host and client from separate internet connections before considering this phase complete.

## Results so far

- The pinned plugin parses in Godot 4.7.2 after its first editor scan.
- A client connected to the GD-Sync service and retrieved the public lobby list.
- A public POC lobby was visible to a separate browse-mode client and retained its POC tags.
- Two local editor-headless proof clients created and joined a private lobby, then exchanged an exposed remote-call probe and acknowledgement.
- A direct `lobby_leave()` from the joining client did not produce a `client_left` event on the host during a local twenty-second test. Treat host-side disconnect detection as unresolved and repeat it on the external-network gate before using the signal in gameplay.
- An exported Windows proof client connected and browsed lobbies.
- Two local instances of the exported Windows proof client completed the same private-lobby and probe exchange.
- `tests/race_shell_check.gd` passes without GD-Sync startup errors because the plugin is not a global autoload.

## Required external-network gate

The proof is not complete until all checks below pass on two clean Windows machines on distinct internet connections:

1. Run an exported host with no port-forwarding configuration.
2. Join using the displayed room code from the second exported client.
3. Confirm both clients report `connected`, `lobby_joined`, and both probe payloads.
4. Close the joining client and verify the host reports `DRUGI KLIENT OPUŚCIŁ POKÓJ`.
5. Start a public test lobby, browse it from the second machine, and confirm its metadata is visible.
6. Start two join attempts for the same public room and record the expected single success and single full/closed failure.
7. Confirm `addons/GD-Sync/keys.cfg` is ignored and no API key appears in the build logs or repository status.

If the external-network test fails, capture only the non-sensitive connection error code and stop the multiplayer implementation. Reassess EOS or Nakama before changing race gameplay.
