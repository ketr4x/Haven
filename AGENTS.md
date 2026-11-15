# Rezonans

## INFO

Rezonans is a single-player, full-screen parkour time trial built with Godot 4.7 Forward+. The entry scene is `scenes/game/race.tscn`. The active course is generated deterministically from one seed in one `PlayerWorld`. `R` restarts the current seed, `N` generates a new seed, and `Escape` pauses an active race.

The project is migrating from passive, split-screen echolocation to **Echo-Hook & Petrified Echo**: mouse-aimed waves bounce from terrain, reflected waves can become temporary one-way platforms, and the player can grapple and swing from them. It is a solo time trial; it does not use Ghost Racing or a leaderboard.

The game’s player-facing text is in Polish. Use Polish for new UI copy, prompts, and other text shown to players. Keep source code, identifiers, comments, and project documentation in English.

### Repository layout

```text
assets/                 Art, fonts, palette resources, shaders, and audio placeholders
resources/tiles/        Shared 48-pixel terrain TileSet
scenes/effects/         Echo, frozen echo, blue block, palette, reveal-ring, and sound-wave scenes
scenes/game/            Race, player-world, movement-lab, and generator-lab scenes
scenes/levels/chunks/   Authored start, traversal, fallback, and finish chunk scenes
scenes/player/          Player scene
scripts/effects/        Echo, frozen platform, grid, ring, and wave behavior
scripts/game/           Race state, player-world, and finish-area behavior
scripts/generator/      Course chunk metadata and seeded course generation
scripts/player/         Player movement and future grapple behavior
tests/                  SceneTree checks for race, waves, echo, and generation
```

Course chunks are scene instances described by `CourseChunk`. A chunk has entry and exit markers, terrain cells on a 48 × 48 grid, width and difficulty metadata, and optional player-spawn or finish markers. `CourseGenerator` places a start chunk, a configurable number of compatible traversal chunks, and a finish chunk. It uses a seeded `RandomNumberGenerator` for traversal selection.

### Development conventions

- For non-trivial changes, create and switch to a dedicated branch before editing. Use a descriptive prefix such as `feature/`, `fix/`, `chore/`, `docs/`, or `test/`.
- Push completed non-trivial branches and merge them through a pull request when repository hosting and branch protection are available. Keep `main` releasable and avoid pushing directly to protected `main`.
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
- `race.tscn` now contains one direct, full-screen `PlayerWorld`. The split-screen containers, second `SubViewport`, second player world, divider, and reflected right-to-left course have been removed.
- The race keeps title, three-second countdown, racing, paused, and finished states for one time-trial player.
- Restarting repeats the current seed. Generating a new course selects a different random seed. The current seed is shown in the HUD.
- The race HUD and title flow are Polish and no longer present a second local player.
- The echolocation overlay now preserves the full rendered scene. Echo hits add a cyan-white afterglow and cannot hide terrain by fading it to black.
- `PlayerWorld` has a dark Luap-40 blueprint grid that drifts with parallax behind the course.
- The Input Map now defines unified movement, jump, slam, mouse wave, freeze/grapple, restart-seed, next-seed, and pause actions. Active gameplay reads only these actions.
- The player no longer builds loudness or emits automatic footstep, landing, shout, or BigScream pulses.
- Holding the left mouse button provides a 1.2-second real-time focus window at 0.25 time scale. The player draws a one-bounce dashed aim path, marks noise foam with a red X, and fires a directional wave on release.
- Directional waves travel at 1,500 px/s, are white before their first impact, and become cyan after a normal-based reflection. Only reflected waves are eligible for freezing.
- `FrozenEcho` creates a 168 px, ±40-degree, four-second, one-way crystal platform. The world limits it to two live instances and flashes an afterglow at creation and expiry.
- An airborne player can attach to a nearby FrozenEcho or one created while holding freeze/grapple. The tether preserves tangential momentum, accepts left/right swing input, renders as a vibrating string, and releases with a sling impulse.
- FrozenEcho surfaces provide an Echo-Slide speed injection and bounce a hard landing or jump. A player created inside a new echo is moved above its one-way surface.
- Grapple speed beyond `supersonic_speed` activates the cyan sonic cone and smoothly widens the camera view.
- Falling below the boundary now opens a 0.4-second Bungee Bounce Back prompt. One charge uses the latest FrozenEcho or current-chunk checkpoint, then recharges over 8 seconds; a missed window respawns at that checkpoint.
- `BlueResonanceBlock` is a 48-pixel generated shortcut barrier. A reflected wave or supersonic player shatters it.
- Course generation now checks `requires_echo_hook` and `allows_wall_jump`, adds blue-block shortcut barriers to branching chunks, and retains the tile-aligned course roof as an Echo-Catcher above traversal gaps.
- Noise foam is a dark, porous collision surface that absorbs waves instead of reflecting them.
- The traversal set includes sixteen static, 16-cell-wide stacked-path structures. Each has separate lower, middle, and upper platforms with gaps for jumping between paths, plus canopy, channels, crossing, fork, gallery, ladder, overlook, switchback, and dead-end layouts.
- Every generated course has a tile-aligned roof above its highest terrain and a fall boundary below its lowest terrain.
- The race shell SceneTree check now covers the single-world hierarchy, same-seed restart, new-seed generation, full-screen afterglow, parallax grid, state flow, pause, and finish.
- The committed `t3.json` exposes actions to start the Godot game and build a Windows export.
- A Windows Desktop export preset writes the game to `build/windows/Rezonans.exe`; generated export files are ignored.

## TO DO

- Add square debris/particle effects for blue-block destruction and displaced FrozenEcho replacement.
- Extend the SceneTree checks for the new input map, bounced waves, frozen echoes, grapple physics, Bungee Bounce Back, and blue blocks. Do not run the full SceneTree suite unattended because it can hang.
- Playtest roof/catcher placement over each authored gap layout and adjust blocker positions after in-editor traversal testing.

## NEXT STEPS

**Tune FrozenEcho and grapple movement.** Validate one-way collision, the two-platform replacement rule, swing control, and release momentum before adding the remaining recovery and destructive-terrain systems.
**Playtest the full-screen presentation.** Confirm that all terrain remains readable at normal and high camera speeds and that the blueprint grid does not compete with collision outlines.
