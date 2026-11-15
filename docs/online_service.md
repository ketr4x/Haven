# Online Service Boundary

`OnlineService` is a project-wide autoload configured in `project.godot`. It is an instance of `GdSyncOnlineService`, but game code must use its service API and signals rather than call GD-Sync directly.

The autoload is idle at launch. `connect_online()` creates the GD-Sync client only when an online menu or match flow requests it. Local PvP therefore runs without a connection attempt or GD-Sync scene-tree startup work.

## Public API

```gdscript
OnlineService.connect_online()
OnlineService.disconnect_online()
OnlineService.create_lobby(lobby_name, password, is_public, player_limit, tags)
OnlineService.join_lobby(lobby_name, password)
OnlineService.leave_lobby()
OnlineService.list_public_lobbies()
OnlineService.send_message(message)
```

Use `OnlineProtocol.make_message(kind, match_id, sequence, payload)` for every remote gameplay message. The adapter rejects messages with an unsupported kind, an incompatible protocol version, an invalid match ID, a negative sequence, or a non-dictionary payload.

The supported message kinds are `hello`, `race_setup`, `course_ready`, `race_start`, `player_status`, `player_died`, `player_finished`, `match_result`, and `rematch_vote`.

## Signals

```gdscript
online_connected(client_id)
connection_failed(reason)
online_disconnected
lobby_created(lobby_name)
lobby_joined(lobby_name)
lobby_join_failed(lobby_name, reason)
lobbies_listed(lobbies)
peer_joined(client_id)
peer_left(client_id)
message_received(sender_id, message)
operation_rejected(operation, reason)
```

The adapter is the only code that loads `addons/GD-Sync/MultiplayerClient.gd`. `Race`, `PlayerWorld`, and UI code must not depend on the GD-Sync singleton or plugin-specific signals.

## Tests

`tests/online_service_check.gd` uses `LocalMatchService`, an in-memory service double. It verifies connection state, public-lobby data, outgoing protocol validation, incoming message validation, and rejection handling without requiring internet access or GD-Sync credentials.

`scenes/game/gd_sync_poc.tscn` exercises the same `OnlineService` adapter against GD-Sync. Keep it as a manual export and external-network regression check.
