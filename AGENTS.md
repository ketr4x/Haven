# Rezonans

## INFO

Rezonans is a local two-player, horizontal split-screen parkour race built with Godot 4.7 Forward+. The entry scene is `scenes/game/race.tscn`. Player 1 plays in the top viewport with `A`/`D` to move, `W` to jump, `S` for a cosmetic shout, `E` for `BigScream-`, and `Q` for `BigScream+`. Player 2 plays in the bottom viewport with left/right to move, up to jump, down for a cosmetic shout, Page Down for `BigScream-`, and Page Up for `BigScream+`. `R` restarts the current seed, `N` increments the seed and generates a new course, and `Escape` pauses during a race.

The game’s player-facing text is in Polish. Use Polish for new UI copy, prompts, and other text shown to players. Keep source code, identifiers, comments, and project documentation in English.

Each viewport has its own `PlayerWorld`, player, generated level, waves, finish area, camera, and echo overlay. The race controller gives both worlds the same seed so they generate the same chunk sequence without sharing physics or rendering. Player 2's course is reflected horizontally and runs right-to-left.

The game loop centers on movement-controlled echolocation. Every footstep emits a pulse, with every fourth step producing a long-range pulse. Jumps and wall jumps emit modest pulses, and a hard landing sends powerful sonar ahead. Manual shout input is cosmetic. Invisible sound probes and visible pixel arcs move at the same speed, reflect from collision geometry, and drive exact tile afterglow. A reflected wave opens a 200-millisecond jump-timing window; catching it with a jump grants Echo-Surf speed and height.

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

Course chunks are scene instances described by `CourseChunk`. A chunk has entry and exit markers, terrain cells on a 48 × 48 grid, width and difficulty metadata, and optional player-spawn or finish markers. `CourseGenerator` places a start chunk, a configurable number of compatible traversal chunks, and a finish chunk. It uses a seeded `RandomNumberGenerator` for traversal selection.

### Development conventions

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
- The Input Map defines both players' movement, jump, cosmetic shout, `BigScream-`, and `BigScream+` actions, plus restart, new-course, and pause actions.
- `race.tscn` presents independent top and bottom `SubViewport` player worlds.
- The race has title, three-second countdown, racing, paused, and finished states. A player entering the finish area wins.
- The race retains an integer seed. Restart reuses it, and the new-course action increments it. Both player worlds generate courses from that same seed. Player 2 receives a horizontal reflection of the same chunk sequence.
- The player supports horizontal acceleration and deceleration, gravity, coyote time, jump buffering, wall sliding, wall jumping, landing particles, and exported tuning values.
- Players have loudness clamped from 0 to 100. Running, wall contact, and hard landings add loudness, while idle decay reduces it. Manual shouts are cosmetic and cannot add loudness or reveal the level.
- Intro pulses, footsteps, jumps, wall jumps, landings, and concentrated screams emit independent, invisible `SoundWave` probes inside the same visible arc as their pixel front. Both probes and pixel fronts inherit the player's velocity at emission, travel at 900 pixels per second relative to that frame, and share a maximum path distance, keeping collision light synchronized with the drawn wave.
- Every footstep creates a small pulse (scaled up 2.5× from the initial prototype), while every fourth footstep creates a quieter long-range pulse capable of returning for Echo-Surf. Jumps, soft landings, and wall jumps emit mid-sized pulses, and hard landings create the strongest regular directional sonar.
- Each probe collision flashes the exact reached tile contour at full brightness and fades it over 3 seconds. Dark obstacles, ceilings, and vertical walls remain hidden until hit, while top walkable floor surfaces across the viewport stay permanently visible as a crisp Luap-40 outline.
- Each visible outgoing impulse draws seven 70-degree arcs from a fixed emission point moving at the player's initial velocity, staggered by 50 milliseconds. Arcs consist only of individually snapped 1 × 1 pixels, use deterministic radial waviness, fade as their radii grow, and can reach 1,680 pixels. Live collision limits prevent pixels from drawing through terrain while still touching floor and wall surfaces.
- A reflected eligible wave opens a 200-millisecond timing window before or after contact. Jumping inside that window grants Echo-Surf, immediately raising horizontal speed and jump velocity; merely receiving a regular reflected wave grants no automatic boost.
- `BigScream-` emits a red 30-degree concentrated wave. A return from ordinary terrain applies a 0.5-second movement slow without stunning the player. Its planned purpose is destroying blue blocks once that block type exists.
- `BigScream+` emits a yellow 30-degree concentrated wave. Its return immediately grants a speed boost and opens the same 200-millisecond timing window for additional jump height.
- A sufficiently fast horizontal obstacle impact applies up to 40 milliseconds of player-local hitstop, pixel-stepped camera shake, spring recoil, and square debris without affecting the other viewport.
- Return effects remain owner-local: Echo-Surf timing, `BigScream-` slow, and `BigScream+` boost affect only the player who emitted that pulse.
- Scene-owned audio feedback plays distinct cues for footsteps, jumps, wall jumps, landings, shouts, wave bounces, returned waves, and finishes.
- The project includes a Luap-40 lookup texture and post-process scene, a collision-local echolocation shader, a pixel-crisp source-front effect, optimized invisible sound probes, a terrain TileSet, a font, and staged logo and player-sheet artwork.
- Course generation selects traversal chunks deterministically, requires a safe landing flag, checks basic grid geometry and width metadata, limits difficulty changes to one tier, aligns chunk markers, and uses a fallback chunk when no traversal candidate is compatible.
- SceneTree checks exist for the race shell, deterministic generation, sound-wave behavior, and the owner-local echo path.
- The current runnable visual scenes, `race.tscn`, `movement_lab.tscn`, and `generator_lab.tscn`, instance the Luap-40 post-process scene.

## TO DO

- Add destructible blue blocks and connect them to `BigScream-`; the concentrated red wave and future-purpose documentation exist, but no blue block type is authored yet.
- Playtest the two-player keyboard layout in Godot, including movement plus jump, `BigScream-`, or `BigScream+` combinations, to identify keyboard ghosting.
- Define simultaneous-finish behavior. The current winner is the first player whose finish signal reaches the race controller.
- Confirm whether a rematch should return to the title state, as it currently does, or start immediately.
- Add or verify real traversal validation. The current generator does not test reachability, jump envelopes, chunk overlap, connection safety, or landing safety beyond the chunk metadata and grid checks.
- Use the existing `allows_wall_jump` and `requires_shout` chunk metadata in generator compatibility or validation. They are declared but are not read by `CourseGenerator`.
- Verify that all configured course chunks allow a player to reach the finish. The generator currently assembles chunks but has no pathfinding or traversal simulation.
- Validate the existing authored chunk set before expanding it. The generator references start, traversal, fallback, and finish chunk scenes, including gap, wall-jump, and bounce-reward layouts.
- Add persistent per-player loudness and boost-duration indicators. Current visual feedback is limited to reveal rings and the echo overlay.
- Add a committed export preset and test an exported build. No export preset is tracked in this repository.
- Integrate the staged logo and player sprite sheet only when the corresponding menu and animation work is implemented. They are present in `assets/art/` but are not referenced by the active scenes.

## NEXT STEPS

**Playtest wave timing and darkness.** Confirm that 900-pixel-per-second fronts reach 12–15 tiles ahead, obstacle contours light exactly on contact, and the narrow 5% floor guide is enough for high-speed movement.
**Tune Echo-Surf.** Test the 200-millisecond jump window, 1.8× launch speed, 1.38× jump velocity, and every-fourth-step return opportunities on wall-jump and gap chunks.
**Tune concentrated screams.** Validate `E/Q` and `Page Down/Page Up`, the shared 0.8-second cooldown, the 0.5-second red-wave slow, and the yellow-wave speed-plus-jump reward before blue blocks are authored.
**Tune obstacle impact feel.** Verify that 35 milliseconds of local hitstop, five-pixel camera shake, recoil, and square debris feel responsive without interfering with Echo-Surf or the other player.
