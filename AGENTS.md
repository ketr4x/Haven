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

- Before starting work on a feature or subject, create and switch to a dedicated git branch named `feature/<subject>` (for example, `feature/jumping-overhaul`), and keep that work on the branch until it is ready to merge.
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
- Do not commit generated `.godot/` content, imports, logs, generated exports, or machine-local files. `local.agents.md` contains untracked, machine-specific notes and is not repository policy.
- When adding art or UI, use the existing Luap-40 palette and preserve pixel-crisp rendering. The logo and player sheet are staged assets, not active gameplay art.

## DONE

- The Godot project is configured for Forward+ and launches `scenes/game/race.tscn`.
- The Input Map defines both players' movement, jump, and shout actions, plus restart, new-course, and pause actions.
- `race.tscn` presents independent top and bottom `SubViewport` player worlds.
- The race has title, three-second countdown, racing, paused, and finished states. A player entering the finish area wins.
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

## TO DO

- Playtest the two-player keyboard layout in Godot, including movement plus jump or shout combinations, to identify keyboard ghosting.
- Define simultaneous-finish behavior. The current winner is the first player whose finish signal reaches the race controller.
- Confirm whether a rematch should return to the title state, as it currently does, or start immediately.
- Add or verify real traversal validation. The current generator does not test reachability, jump envelopes, chunk overlap, connection safety, or landing safety beyond the chunk metadata and grid checks.
- Use the existing `allows_wall_jump` and `requires_shout` chunk metadata in generator compatibility or validation. They are declared but are not read by `CourseGenerator`.
- Verify that all configured course chunks allow a player to reach the finish. The generator currently assembles chunks but has no pathfinding or traversal simulation.
- Playtest the authored chunks, including foam-ceiling clearance, stacked paths, roof clearance, and fall reset, before expanding the terrain set further.
- Add persistent per-player loudness and boost-duration indicators. Current visual feedback is limited to reveal rings and the echo overlay.
- Add a committed export preset and test an exported build. No export preset is tracked in this repository.
- Integrate the staged logo and player sprite sheet only when the corresponding menu and animation work is implemented. They are present in `assets/art/` but are not referenced by the active scenes.

## NEXT STEPS

**Make the core loop readable.** Add a per-player loudness indicator and a visible boost-duration cue. Test whether players can tell that loudness affects their wave, noise foam blocks it, and a returned wave causes the boost.
**Playtest terrain features.** Tune foam placement and the readability of branching platform choices while both players race through the same seed.
**Playtest the new cues.** Verify that the movement, wave, boost, landing, and finish sounds stay distinct and balanced for two simultaneous players.
