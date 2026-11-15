# Player Sprite Sheet & Slide Animation Guide

## Sprite Sheet Overview
The player character uses a `160×80` pixel sprite sheet divided into a `10×5` grid of `16×16` pixel frames:
- **Player 1 (Maroon Cloak)**: `res://assets/art/player.png`
- **Player 2 (Blue Cloak)**: `res://assets/art/playe1r.png`

Both textures are rendered with `CanvasItem.TEXTURE_FILTER_NEAREST` and scaled to `2.5×` (`40×40` pixels) inside `scenes/player/player.tscn` (`PlayerSprite`) so the cloaked runner aligns cleanly with the `24×36` collision box.

---

## Row Breakdown (5 Rows of `16×16` Frames)

| Row (0-indexed) | Y Offset | Total Frames | Frame Columns (`x`) | Animation Name | Looping Behavior |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Row 0** (1st) | `y = 0` | `9` | `0..8` | `idle` | Loops continuously (`0..8`) |
| **Row 1** (2nd) | `y = 16` | `10` | `0..9` | `run` | Loops continuously (`0..9`) |
| **Row 2** (3rd) | `y = 32` | `8` | `0..7` | `slide` *(documented for future implementation)* | Frame 1 (`x = 0`) and Frame 8 (`x = 7`) are idle transition poses; Frames 2–7 (`x = 1..6`) are the active slide |
| **Row 3** (4th) | `y = 48` | `8` | `0..7` | `flip_start` / `flip_loop` | Frame 1 (`x = 0`) is idle, Frame 2 (`x = 1`) is wind-up (`flip_start`, non-looping), and Frames 3–8 (`x = 2..7`) loop continuously during the air flip (`flip_loop`) |
| **Row 4** (5th) | `y = 64` | `5` | `0..4` | `jump` / `fall` / `land` | Rising (`jump`) plays `3, 2, 1, 0` (reversed); falling (`fall`) plays `0, 1, 2, 3` and holds on Frame 4 (`x = 3`, second-to-last frame) while airborne; Frame 5 (`x = 4`, last frame) is the crouched landing frame (`land`) |

---

## Row 2 (3rd Row): Slide Animation Specification (For Future Implementation)

The **3rd row** (`y = 32..47`, 8 frames total across `x = 0..7`) contains the **Slide** animation. Per design requirements, slide is **not** active in gameplay yet, and this document serves as the reference for anyone implementing a ground slide mechanic later on.

### Frame-by-Frame Layout (`y = 32`, `width = 16`, `height = 16`)
1. **Frame 1 (`col = 0`, `Rect2(0, 32, 16, 16)`) — Entry Idle Pose**:
   - Upright idle transition frame entering the crouch/slide.
2. **Frames 2–7 (`col = 1..6`, `Rect2(16..96, 32, 16, 16)`) — Active Slide**:
   - Low-profile sliding frames where the character drops down and slides forward along the floor.
   - Specifically:
     - `col = 1` (`Rect2(16, 32, 16, 16)`): Transition into low slide.
     - `col = 2..5` (`Rect2(32..80, 32, 16, 16)`): Full low-profile slide hold/loop frames (suitable for holding or looping while sliding under low `1`-tile gaps).
     - `col = 6` (`Rect2(96, 32, 16, 16)`): Recovery transition rising out of the slide.
3. **Frame 8 (`col = 7`, `Rect2(112, 32, 16, 16)`) — Exit Idle Pose**:
   - Upright idle pose returning smoothly to `idle` or `run`.

### Recommended Implementation Steps When Adding Slide Later
- Split Row 2 into three `SpriteFrames` clips or manage frame indices in `scripts/player/player.gd`:
  - `slide_enter`: columns `0, 1` (`loop = false`).
  - `slide_loop`: columns `2, 3, 4, 5` (`loop = true` while slide velocity/timer is active).
  - `slide_exit`: columns `6, 7` (`loop = false`, transitioning back to `idle` or `run`).
- Lower the `CollisionShape2D` height during `slide_loop` if the slide is intended to pass underneath low ceiling obstacles.
