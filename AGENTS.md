# Rezonans

## Project brief

**Rezonans** is a two-player horizontal split-screen parkour race in pitch darkness. Player 1 races in the top viewport and Player 2 races in the bottom viewport. Both use the same generated course and do not collide.

Movement raises **loudness**, a player-owned value from 0 to 100. Loudness is the strength of that player’s echolocation. Running, Sonic Shout, and wall movement raise it. When a player is idle it decays to 0.

Soundwaves reflect from solid geometry but do not reveal terrain at their impact point. A reflected wave activates echolocation only when it returns to its owner. The resulting edge reveal and its radius are proportional to the wave’s captured loudness. Catching that returned wave also grants the temporary speed and jump boost.

The 24-hour Haven build targets **Windows PC** with the Godot 4.x Forward+ renderer. It must be playable locally by two people on one keyboard. Peer voters are likely to play for five minutes or less. The game must therefore get them into a clear race in under 15 seconds, show the Sonic Shout in the first 20 seconds, and let them finish a satisfying race in 60 to 90 seconds. The game generates a new fair course each run from a seed. Art may begin as deliberately readable placeholders and be replaced with hand-made pixel art when the playable loop is stable.

Local PvP is required. Party and Matchmaking may appear in the menu only as unavailable options. Do not build a backend, fake online play, or sacrifice the local race for networking.

## Product priorities

1. Deliver the first playable race in under 15 seconds with no account, lobby, or long instructions.
2. Make the Sonic Shout look and sound striking in the first 20 seconds.
3. Let a first race finish in 60 to 90 seconds, then offer an instant rematch.
4. Make the loudness-to-echolocation relationship readable: louder actions create larger waves and a larger returned-wave reveal.
5. Responsive movement and fair generated courses come before art polish.
6. Procedural generation must use small authored chunks and validation, not unrestricted random terrain.
7. Prefer scene composition and exported tuning values over node construction in code.

## Scope

### Required vertical slice

- Two-player local keyboard input and top/bottom split-screen.
- Coyote time, jump buffering, wall slide, wall jump, and radial Sonic Shout pulses.
- Player loudness from 0 to 100, raised by running, Sonic Shout, and wall movement, then decaying while idle.
- Waves whose physical size and return-reveal radius are proportional to captured loudness.
- Predictable wave reflection and an edge-only echolocation reveal that activates only when a reflected wave reaches its owner.
- A returned-wave boost for the owner.
- A deterministic seeded course generator which assembles safe, authored chunks.
- A seed retained internally for reproducible QA, a same-seed rematch, and a new-seed rematch.
- A 5-second title/controls screen, a 3-second countdown, finish trigger, winner screen, pause, and quick restart.
- A Windows Forward+ export tested outside the editor.

### Explicit cuts for this jam

- Real party service, matchmaking, online synchronization, NAT traversal, dedicated servers, and anti-cheat.
- Ranked leaderboard, accounts, persistence, progression, cosmetics, and replays.
- Unbounded procedural terrain, multiple game modes, AI opponents, and more than one generation biome.
- Per-tile fog-of-war shaders unless the basic local reveal is complete and already fun.
- Seed entry, seed displays in the normal HUD, long tutorials, and settings menus. Keep a developer-only seed override for testing.

## Five-minute peer-vote experience

The opening must work for people who will never read a README:

1. **0–5 seconds:** title card shows both control schemes beside a prominent `Press any movement key` prompt.
2. **5–8 seconds:** a three-second countdown begins as soon as both players move or the first player presses a key.
3. **8–30 seconds:** the start chunk presents a wall or corridor where a Sonic Shout immediately produces a visible large wave. When it returns, show a strong edge flash, ring, boost aura, and bounce sound.
4. **30–90 seconds:** one clean race uses a gap, a wall-jump route, and one obvious returned-wave shortcut. Never require the boost to finish.
5. **Finish:** show the winner, a one-line “Catch your bounced wave for a boost” reminder, and large `Rematch` / `New course` actions.

The first generated chunk must always be a curated tutorial-start chunk. Randomization begins after that. Use the same 60–90 second target length for every valid seed.

## Technology and conventions

- Godot 4.x, GDScript, 2D game, **Forward+** renderer.
- Windows is the shipping target. Open, save, and run scenes from Windows Godot.
- WSL may edit text and run Git, but must not modify scene/import files while another person has them open in Godot.
- Use `snake_case` for files, nodes, methods, variables, and signals. Use `PascalCase` for `class_name` types.
- Use typed GDScript for public fields, function arguments, and return values where practical.
- Expose movement, wave, generator, and boost values through `@export` so they can be tuned without script edits.
- Use signals in past tense, for example `wave_bounced`, `boost_started`, and `race_finished`.
- Comments explain a constraint, unit, or non-obvious decision. Do not add decorative section banners or comments that paraphrase code.

## Keyboard controls

Use these actions in **Project Settings > Input Map**. Do not read physical keys directly from gameplay code.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move left/right | `A` / `D` | Left / Right arrows |
| Jump | `W` | Up arrow |
| Sonic Shout | `S` | Down arrow |
| Restart | `R` | `R` |
| Pause | `Escape` | `Escape` |

Test the chosen keyboard in the first hour. If it ghosts when both players hold movement plus action keys, move Player 1’s shout to `F` or use an alternate tested layout. Display the final controls in the start screen.

## Visual and art direction

- **Aesthetic**: Low-bit pixel art with a dark, atmospheric mood. The world sits in near-darkness while player silhouettes, revealed terrain, and soundwaves pop with high contrast.
- **Color palette (`Luap-40`)**: All new art, UI, particles, placeholder polygons, and shader tints must use colors from [`assets/palettes/luap_40.hex`](assets/palettes/luap_40.hex) rather than arbitrary RGB values:
  - Dark backgrounds & deep shadows: `#1a1a1a`, `#331a33`, `#33291f`, `#363636`, `#403326`, `#433057`
  - Muted terrain & midtones: `#464a73`, `#515151`, `#546799`, `#574639`, `#597080`, `#66294c`, `#6d6d6d`, `#733453`, `#735f4b`, `#888888`, `#8c3f52`
  - Cool / cyan / blue accents (waves, reveals, cool highlights): `#6699cc`, `#6da18a`, `#82b5d9`, `#86bf8f`, `#a1d5e6`, `#b5d9a3`, `#c2f2f2`
  - Warm / coral / rose accents (player contrast, alerts, boost): `#bd555f`, `#bf6979`, `#c4736c`, `#c98f8f`, `#d99f82`, `#d9b898`, `#d9b8ad`, `#b39374`
  - Light & neutral highlights (text, sharp rims, flashes): `#a3a3a3`, `#bfbfbf`, `#dadada`, `#e0e6c3`, `#e6cca1`, `#e6d4c3`, `#f0ebc0`, `#f5f5f5`
- **Typography**: Use `KiwiSoda` ([`assets/fonts/kiwi_soda.ttf`](assets/fonts/kiwi_soda.ttf)) for menus, HUD, and overlays. Keep pixel-aligned sizes for crisp rendering.
- **Pixel crispness**: Keep `Nearest` texture filtering on pixel sprites, tilesets, and UI textures so low-bit assets never blur.
- **Logo asset**: [`assets/art/rezonans_logo.png`](assets/art/rezonans_logo.png) is staged in `assets/art/` for future menu/title use; do not integrate it into active scenes yet.
- **Post-processing (planned)**: Once core gameplay and art assets are in place, add a final CRT-style screen shader (scanlines, subtle phosphor bloom/aberration, and dark vignette) tuned so split-screen text and fast parkour cues remain crisp and legible.

## Project layout

```text
assets/
  art/
  audio/
  fonts/
  palettes/
scenes/
  effects/
  game/
  generator/
  levels/
    chunks/
  menus/
  player/
scripts/
  effects/
  game/
  generator/
  player/
  ui/
resources/
  tiles/
  chunks/
tests/
```

Keep a scene and its primary script near each other. `race.tscn` composes the shared level, generator, two player instances, split-screen display, and HUD. `player.tscn` owns player movement. `sound_wave.tscn` owns wave lifetime and reflection. Individual course chunks live under `scenes/levels/chunks/`.

## Scene-first construction

Use the editor for visual, static, and tuned content:

- Build `player.tscn`, `sound_wave.tscn`, HUD, menu, visual effects, TileSet, and course chunks in the scene editor.
- Build each generator chunk as a normal scene with `TileMapLayer` collision, art, and `Marker2D` entry/exit markers.
- Place `Marker2D` nodes for player starts, chunk exits, finish locations, and camera bounds.
- Use exported `PackedScene` arrays to assign chunks to the generator.
- Use scripts for input routing, player state, deterministic selection, validation, wave math, and runtime spawning.

### Grid terrain

- All course collision and obstacle art must be cells in a `TileMapLayer`, never individual `StaticBody2D` or `Polygon2D` obstacle nodes.
- Use the shared `resources/tiles/terrain_tileset.tres` with a 48 × 48 pixel grid. A chunk declares its grid cells and its setup script places them into its scene-owned `Terrain` TileMapLayer.
- Keep entry, exit, player-spawn, and finish markers on that same 48-pixel grid. The Terrain layer uses its fixed `(-24, -24)` offset so grid coordinates describe cell centres.
- Decorative nodes may sit outside the grid only when they have no collision and do not represent a playable obstacle.
- Generator validation must reject chunks whose terrain or connection markers do not follow the common grid.

Only instantiate runtime content in code: selected chunk scenes, waves, transient rings, and result overlays. Do not assemble ordinary players, tilemaps, UI, collision shapes, or static art node-by-node in code.

## Core architecture

### Split-screen race

`race.tscn` owns two independent `PlayerWorld` scene instances, one inside each `SubViewport`. Both worlds receive the same race seed and therefore generate the same chunk sequence, but they never share physics, rendering, players, waves, or collision bodies.

Keep seed parity and presentation isolation explicit:

- Generate Player 1’s and Player 2’s course independently from the identical seed.
- A player world contains exactly one player, one generated level, one wave container, one finish area, one camera, and one echo overlay.
- Neither player, wave, reveal, nor boost can be observed or collide across viewports.
- `race.tscn` owns only the seed, result state, countdown, rematch, and global UI.

### Procedural course generation

Every run has an integer `seed` retained by the race manager for reproducible QA and rematches. The normal player HUD should not show a raw seed; show it only in a developer overlay or result/debug screen when needed. A same-seed rematch reproduces the exact layout. A new-seed rematch generates a different layout. Seed the generator once, never use unseeded `randf()` or `randi()` during layout generation.

Start with a fixed recipe:

```text
start chunk -> 4 to 6 traversal chunks -> finish chunk
```

A chunk scene needs entry and exit `Marker2D` positions and exported metadata such as:

- `difficulty` from 1 to 3
- `min_width` and `max_width`
- `allows_wall_jump`
- `requires_shout`
- `has_safe_landing`

The generator chooses from compatible chunks with a seeded `RandomNumberGenerator`, aligns each new entry marker with the previous exit marker, and rejects invalid candidates. Validation is deliberately simple: no overlapping chunk bounds, a reachable exit, a safe landing after each required jump, and no difficulty jump larger than one tier.

First prove generation using 4 flat placeholder chunks that only connect cleanly. Add a gap, wall-jump, and bounce-reward chunk one at a time. If a chunk cannot be validated, replace it with a known-safe chunk. The generator must always produce a playable course, even if variety is low.

### Player contract

`Player` receives exported input action names and a player id. It emits events other systems consume:

```gdscript
signal landed(position: Vector2)
signal wall_jumped(position: Vector2, normal: Vector2)
signal sonic_shouted(origin: Vector2, direction: Vector2)
```

`Player` also owns the loudness state. Loudness is clamped to `0.0` through `100.0`, starts at `0.0`, and decays to `0.0` whenever its source actions stop. All rates and one-shot gains are exported tuning values. Running and wall movement add loudness continuously. Sonic Shout adds a one-shot loudness amount before it captures its wave strength.

Store coyote time and jump buffering as short seconds-based timers. Apply the rebound boost as a single timed state with a visible multiplier and a reliable reset. Tune movement in a small movement-lab scene before it is used in generated chunks.

### Soundwave contract

A soundwave is a circular pulse, not a directional projectile. A pulse expands visibly from its owner in every direction while a bounded set of invisible radial physics rays carries the reflected return paths. The pulse scene has a ring/trail child, owner id, captured loudness, and lifetime. Spawn it through one narrow factory method or manager.

When a player shouts or makes a footstep, capture that player’s loudness. Use it to scale the pulse’s visible radius and the eventual echolocation radius. Emit evenly spaced physics rays in all directions. Each ray reflects from solid TileMapLayer geometry and may return to the owner. Wall impacts produce bounce feedback only. They do not reveal terrain.

Only a ray with at least one completed bounce can activate its owner. The first reflected ray from a pulse to reach the owner triggers the owner-only edge reveal and boost. Other players never activate or receive its reveal.

### Darkness and echolocation reveal

At loudness `0`, the playable world is black except for each player’s own silhouette and essential UI. Each player silhouette must remain visible at all times, independent of loudness, wave state, and echo return. The level must not become visible merely because a wave bounced.

When a reflected wave reaches its owner, create a short-lived reveal centered on that player. It shows wall, floor, and platform **edges**, not a fully lit level. The radius, line thickness, and ring scale are derived from captured loudness. A low-loudness echo must still reveal at least half of the player’s viewport; a high-loudness echo should cover the full viewport. Keep the largest recent reveal visible for about four seconds before fading it out.

Implement the first version with per-viewport dark overlays and edge sprites/lines that the returning wave activates. Keep the reveal system behind a small interface so that it can later become a shader-based edge mask if time permits. Do not let player one’s reveal appear in player two’s viewport.

## Ownership and 24-hour schedule

| Time | Programmer | Artist | Sound, QA, and testing |
| --- | --- | --- | --- |
| Hour 0–1 | Input Map, folders, base scenes, movement-lab setup | Palette and readable placeholder plan | Keyboard ghosting test, controls sheet, test-case template |
| Hour 1–3 | Run, jump, coyote time, jump buffer, wall movement | Player silhouette and terrain reference | Playtest movement and write reproducible issues |
| Hour 3–5 | Four deterministic placeholder chunks and seeded generator | First player/terrain sprites if ready | Generate 30 seeds; report broken or boring layouts |
| Hour 5–7 | Split-screen race, finish, winner, rematch | Darkness, wave, and HUD assets | Test two-player keyboard race and restart flow |
| Hour 7–10 | Sonic Shout, reflection, reveal, returned-wave boost | Replace visible placeholders, add feedback art | Test boost clarity, collision edge cases, and generated paths |
| Hour 10–14 | Add validated traversal chunks and fix blockers | Art/audio asset integration support | Full-run test matrix and issue triage |
| Hour 14–18 | Menu, pause, seed display, tuning, Windows export | Polish the visible game path | Test export on a second Windows PC if possible |
| Hour 18–24 | Bug fixes and submission only | Cover/title assets | Final regression, fresh-clone test, and recorded evidence |

The programmer owns code and integration. The artist owns art source, palette, and animation exports. The third teammate owns sound selection/implementation support, test cases, issue reports, keyboard testing, and release verification. The third teammate may make small isolated fixes only after reporting the issue and claiming the file.

## GitHub workflow

1. `main` must always open and play.
2. Create narrow branches from current `main`: `feat/movement-lab`, `feat/seeded-generator`, `feat/race-split-screen`, `feat/sound-wave`, `feat/bounce-back-boost`, `art/terrain-pass`, or `fix/seed-validation`.
3. One branch answers one question and has one acceptance test. Do not mix generator code, imported art, and a chunk layout rewrite in one pull request.
4. Rebase or merge current `main` before opening a pull request. The author resolves their conflicts.
5. One teammate performs a quick smoke test before merge. The author tests the merge on `main`.
6. Use imperative commit subjects: `Add jump buffer`, `Generate seeded chunk sequence`, `Tune wave bounce limit`.
7. Record bugs with build/commit, seed, player slot, exact steps, expected result, actual result, and screenshot or clip.

### Agent implementation cadence

- The agent works on one small feature branch at a time, runs headless Godot validation, commits, and pushes it for a teammate to test.
- A teammate confirms visual behavior, keyboard feel, and lack of merge conflicts before the agent merges that branch into `main`.
- After the merge, begin the next feature from current `main`.
- Update this document whenever a new agreed product, technical, ownership, or workflow direction affects future work.
- Use side agents only for independent, bounded work that shortens the critical path, such as a focused code review or an isolated test-plan check. The primary agent remains responsible for integration and final validation.

### Godot merge safety

- Assign one editor owner for every `.tscn`, `.tres`, TileSet, and `project.godot` file.
- Do not make parallel edits to the same scene, TileSet, or chunk scene.
- Add new art as new files. Avoid moving or renaming referenced assets.
- Close Godot before switching branches, pulling, or resolving a scene conflict.
- Resolve `.tscn`, `.tres`, and `project.godot` conflicts manually, then open and run the result in Godot.
- Ignore generated `.godot` editor/import/cache files. Commit only intentional project and source assets.

## Delivery slices and acceptance tests

Merge in this order. Begin the next slice only after the prior one works from a fresh checkout.

1. **Project boot**: Forward+ project opens, `main.tscn` runs, and all keyboard actions exist.
2. **Movement lab**: both input profiles can run, jump, coyote jump, buffered jump, wall slide, and wall jump.
3. **Safe seed**: entering a seed produces the same connected flat placeholder course every time, and 30 generated seeds reach a finish.
4. **Race shell**: two local players have independent top/bottom views; finish, winner, same-seed rematch, and new-seed rematch work.
5. **Wave loop**: Sonic Shout raises loudness, emits a wave sized from its captured loudness, and reflects predictably without revealing terrain at a wall.
6. **Bounce Back**: a reflected wave reaching its owner triggers an owner-only edge reveal and boost. Larger captured loudness produces a larger, more readable reveal.
7. **Generated challenge**: gap, wall-jump, and bounce-reward chunks pass validation and do not create unwinnable courses.
8. **Ship pass**: no errors over multiple complete races, keyboard input works under two players, and the Windows export starts outside the editor.

## Playtest questions

Watch two people play without explaining the intended strategy. Ask:

- Can you immediately tell which keys are yours?
- Does holding movement plus jumping and shouting work on this keyboard?
- Can you tell that running, shouting, and wall movement make your waves larger?
- When a wave returns, can you see level edges without seeing the entire level?
- Did any generated layout feel unfair, confusing, or impossible?
- Is the winner clear and can you restart immediately?

Turn observations into individual issues. Fix unclear controls, broken seeds, and frustrating movement before visual polish.

## Commands and safety

Run Godot and Windows exports from Windows. Use WSL for Git and text edits. Keep the project on the Windows filesystem when possible, accessed in WSL through `/mnt/c/...`, so Godot imports and file watching remain reliable.

Before a merge, run the relevant scene and inspect the Godot Output panel. Before release, run the exported Windows executable, not only the editor run button.
