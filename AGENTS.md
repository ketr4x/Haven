# Rezonans

## INFO

Rezonans is a local two-player, horizontal split-screen parkour race built with Godot 4.7 Forward+. The entry scene is `scenes/game/race.tscn`. Player 1 plays in the top viewport with `A`/`D` to move, `W` to jump, and `S` to shout. Player 2 plays in the bottom viewport with the arrow keys: left/right to move, up to jump, and down to shout. `R` and `N` both generate a new random course, and `Escape` pauses during a race.

The game’s player-facing text is in Polish. Use Polish for new UI copy, prompts, and other text shown to players. Keep source code, identifiers, comments, and project documentation in English.

Each viewport has its own `PlayerWorld`, player, generated level, waves, finish area, camera, and echo overlay. The race controller gives both worlds the same seed so they generate the same chunk sequence without sharing physics or rendering. Player 2's course is reflected horizontally and runs right-to-left.

The game loop centers on loudness and returning sound waves. Running and wall contact raise a player's loudness, while idle time reduces it. Shouting adds loudness and emits a visible ring plus radial physics rays. Rays can bounce from collision geometry. The first ray from a pulse that returns to its emitter after a bounce triggers that player's echo overlay and a temporary movement boost.

### Repository layout

```text
assets/                 Art, fonts, palette resources, shaders, and audio placeholders
resources/tiles/        Shared 48-pixel terrain TileSet
scenes/effects/         Echo, palette, reveal-ring, and sound-wave scenes
scenes/game/            Race, player-world, movement-lab, and generator-lab scenes
scenes/levels/chunks/    Authored start, traversal, fallback, and finish chunk scenes
scenes/player/          Player scene
scripts/effects/        Echo, ring, and wave behavior
scripts/game/           Race state, player-world, and finish-area behavior
scripts/generator/      Course chunk metadata and seeded course generation
scripts/player/         Player movement, loudness, and boost behavior
tests/                  SceneTree checks for race, waves, echo, and generation
```

Course chunks are scene instances described by `CourseChunk`. A chunk has entry and exit markers, terrain cells on a 48 × 48 grid, width and difficulty metadata, and optional player-spawn or finish markers. Chunks may also declare terrain features and a number of dead-end branches. `CourseGenerator` places a start chunk, a configurable number of compatible traversal chunks, and a finish chunk. It uses a seeded `RandomNumberGenerator` for traversal selection.

### Development conventions

- For non-trivial changes, create and switch to a dedicated branch before editing. Use a descriptive prefix such as `feature/`, `fix/`, `chore/`, `docs/`, or `test/`, for example `feature/jumping-overhaul`.
- Push completed non-trivial branches and merge them through a pull request when repository hosting and branch protection are available. Keep `main` releasable and avoid pushing directly to protected `main`. Small, low-risk edits may be made directly when the project workflow permits.
- The AGENTS.md file should be edited with new ideas, adding done things and removing to-dos, as well as adding next steps.
- Use the Godot Input Map actions rather than reading physical keys in gameplay code.
- Use `snake_case` for files, methods, variables, signals, and new node names. Use `PascalCase` for `class_name` types.
- Use typed GDScript for public fields, parameters, and return values where practical.
- Keep tunable gameplay values exported. Name new signals in the past tense, such as `wave_bounced` and `race_finished`.
- Keep static, visual, and tuned content in scenes. Use scripts for runtime behavior, procedural selection, and transient instances.
- Comments should explain constraints, units, or non-obvious decisions rather than paraphrasing code.

### Course-chunk rules

- Keep terrain cells and entry, exit, player-spawn, and finish markers aligned to the shared 48 × 48 grid.
- Use `resources/tiles/terrain_tileset.tres` for course terrain collision.
- Keep collision and visible terrain consistent with each chunk's `terrain_cells` metadata.

### Scene and asset safety

- Do not make concurrent edits to the same `.tscn`, `.tres`, TileSet, or `project.godot` file.
- Add new assets instead of moving or renaming referenced assets unless all references are updated.
- Resolve scene and resource conflicts manually, then open and run the result in Godot.
- Do not commit generated `.godot/` content, imports, logs, generated exports, or machine-local files. When present, use `local.agents.md` for its untracked, machine-specific notes; it supplements but does not override repository policy.
- When adding art or UI, use the existing Luap-40 palette and preserve pixel-crisp rendering. The logo and player sheet are staged assets, not active gameplay art.

## DONE

- The Godot project is configured for Forward+ and launches `scenes/game/race.tscn`.
- The Input Map defines both players' movement, jump, and shout actions, plus restart, new-course, and pause actions.
- `race.tscn` presents independent top and bottom `SubViewport` player worlds.
- The race has title, three-second countdown, racing, paused, and finished states. Each player has a timer that freezes on their finish, and the race remains active until both players finish so the result panel can show both times.
- The race generates a fresh random integer seed for its first course and for every `R` or `N` request. Both player worlds receive that same seed, so their generated routes stay equivalent while Player 2's course is horizontally reflected.
- The player supports horizontal acceleration and deceleration, gravity, coyote time, jump buffering, wall sliding, wall jumping, landing particles, and exported tuning values.
- Players have loudness clamped from 0 to 100. Running and wall contact add loudness; idle decay reduces it. Shouts add loudness before emitting their pulse. Running also emits footsteps.
- Shouts create visible reveal rings and radial `SoundWave` rays. Footsteps create a smaller visible ring. Rays bounce from collision geometry, expire after a lifetime or bounce limit, and may return only after at least one bounce.
- The first returned ray for a pulse activates only its emitting player, triggering that viewport's echo overlay and the player's temporary speed and jump boost. Sonic Shouts provide a brief preview, and movement refreshes a smaller reveal.
- Scene-owned audio feedback plays distinct cues for footsteps, jumps, wall jumps, landings, shouts, wave bounces, returned waves, and finishes.
- The project includes a Luap-40 lookup texture and post-process scene, an echo overlay shader, a sound-wave ring shader asset (the active reveal ring currently uses `Line2D`), a terrain TileSet, a font, and staged logo and player-sheet artwork.
- Course generation selects traversal chunks deterministically, requires a safe landing flag, checks basic grid geometry and width metadata, limits difficulty changes to one tier, aligns chunk markers, caps noise-foam and branching-path frequency, and uses a fallback chunk when no traversal candidate is compatible.
- Noise foam is a dark, porous collision surface that absorbs waves instead of reflecting them.
- The traversal set includes sixteen static, 16-cell-wide stacked-path structures. Each has separate lower, middle, and upper platforms with gaps for jumping between paths, plus canopy, channels, crossing, fork, gallery, ladder, overlook, switchback, and dead-end layouts. The arcade, gap, and well structures use two-tile-thick floors. Every course includes a wall-jump structure: the tower or gauntlet uses opposing static walls and floating ledges for side-to-side climbing. Generation caps branching-path chunks and total dead-end branches per course.
- Every generated course has a tile-aligned roof above its highest terrain and a fall boundary below its lowest terrain. Falling below the boundary pauses that player briefly, then respawns them at the course start.
- SceneTree checks exist for the race shell, deterministic generation, sound-wave behavior, terrain features, fall resets, and the owner-local echo path.
- The current runnable visual scenes, `race.tscn`, `movement_lab.tscn`, and `generator_lab.tscn`, instance the Luap-40 post-process scene.
- The committed `t3.json` exposes actions to start the Godot game and build a Windows export.
- A Windows Desktop export preset writes the game to `build/windows/Rezonans.exe`; generated export files are ignored.
- GD-Sync 1.0.2 is pinned under `addons/GD-Sync/` for a completed proof of concept. `gd_sync_poc.tscn` connects, creates or joins a room-code lobby, browses public lobbies, exchanges an explicitly exposed remote-call probe, and reports a departing peer without registering GD-Sync as a global autoload. Two exported Windows clients on separate connections completed the proof.
- `OnlineService` is an idle project autoload backed by `GdSyncOnlineService`. It creates GD-Sync only when an online flow calls `connect_online()`, provides validated lobby and protocol-message APIs, and has an in-memory `LocalMatchService` test double.

## TO DO

- Playtest the two-player keyboard layout in Godot, including movement plus jump or shout combinations, to identify keyboard ghosting.
- Define simultaneous-finish behavior. Matching finish times currently award the win to Player 1.
- Confirm whether a rematch should return to the title state, as it currently does, or start immediately.
- Add or verify real traversal validation. The current generator does not test reachability, jump envelopes, chunk overlap, connection safety, or landing safety beyond the chunk metadata and grid checks.
- Use the existing `allows_wall_jump` and `requires_shout` chunk metadata in generator compatibility or validation. They are declared but are not read by `CourseGenerator`.
- Verify that all configured course chunks allow a player to reach the finish. The generator currently assembles chunks but has no pathfinding or traversal simulation.
- Playtest the authored chunks, including foam-ceiling clearance, stacked paths, roof clearance, and fall reset, before expanding the terrain set further.
- Add persistent per-player loudness and boost-duration indicators. Current visual feedback is limited to reveal rings and the echo overlay.
- Integrate the staged logo and player sprite sheet only when the corresponding menu and animation work is implemented. They are present in `assets/art/` but are not referenced by the active scenes.
- Implement the private friend-room race flow through `OnlineService`, then add public lobby discovery for quick matches. Do not couple `Race`, `PlayerWorld`, or UI directly to the service plugin.
- Add a common-seed event leaderboard and a separate online match-wins board only after the private online race flow works. Treat client results as casual until server-side validation exists.

## NEXT STEPS

**Build the private-room race session.** Use `OnlineService` and `OnlineProtocol` to exchange the room setup, seed, course signature, countdown, finish, and peer-leave events. Keep `Race`, `PlayerWorld`, and scene UI independent of GD-Sync types.
**Ship friend rooms first.** Refactor the race session and player-world configuration so a single full-height local online world can use the existing Player 1 Input Map actions, while local split-screen behavior remains unchanged.
**Build outward from the playable slice.** After private rooms reliably complete a race, add quick-match lobby discovery, the multiplayer menu/result states, and then the fixed-seed event leaderboard.
