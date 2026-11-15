# Player Sprite Sheet & Slide Animation Guide

## Sprite Sheet Overview
The player character uses a `160×80` pixel sprite sheet divided into a `10×5` grid of `16×16` pixel frames:
- **Player 1 (Maroon Cloak)**: `res://assets/art/player.png`
- **Player 2 (Blue Cloak)**: `res://assets/art/playe1r.png`

Both textures are rendered with `CanvasItem.TEXTURE_FILTER_NEAREST`, a `1px` crisp white pixel-art outline (`res://assets/shaders/player_outline.gdshader`), and scaled to `3.0×` (`48×48` pixels, `3×` larger than the raw `16×16` frame) inside `scenes/player/player.tscn` (`PlayerSprite`) so the cloaked runner matches a single `48×48` terrain tile with a `26×44` standing collision box (lowering to `26×24` during a slide).

---

## Row Breakdown (5 Rows of `16×16` Frames)

| Row (0-indexed) | Y Offset | Total Frames | Frame Columns (`x`) | Animation Name | Looping Behavior |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Row 0** (1st) | `y = 0` | `9` | `0..8` | `idle` | Loops continuously (`0..8`) |
| **Row 1** (2nd) | `y = 16` | `10` | `0..9` | `run` | Loops continuously (`0..9`) |
| **Row 2** (3rd) | `y = 32` | `8` | `0..7` | `slide_enter` / `slide_loop` / `slide_exit` | Frames `0..1` (`slide_enter`, non-looping), Frames `2..5` (`slide_loop`, looping while sliding), and Frames `6..7` (`slide_exit`, non-looping recovery) |
| **Row 3** (4th) | `y = 48` | `8` | `0..7` | `flip_start` / `flip_loop` | Frame 1 (`x = 0`) is idle, Frame 2 (`x = 1`) is wind-up (`flip_start`, non-looping), and Frames 3–8 (`x = 2..7`) loop continuously during the air flip (`flip_loop`) |
| **Row 4** (5th) | `y = 64` | `5` | `0..4` | `jump` / `fall` / `land` | Rising (`jump`) plays `3, 2, 1, 0` (reversed); falling (`fall`) plays `0, 1, 2, 3` and holds on Frame 4 (`x = 3`, second-to-last frame) while airborne; Frame 5 (`x = 4`, last frame) is the crouched landing frame (`land`) |

---

## Row 2 (3rd Row): Ground Slide Mechanic & Animation

The **3rd row** (`y = 32..47`, 8 frames total across `x = 0..7`) powers the active ground slide mechanic (`p1_slide` on `S`, `p2_slide` on `Down Arrow`).

### Frame-by-Frame Layout (`y = 32`, `width = 16`, `height = 16`)
1. **Frames 1–2 (`col = 0..1`, `slide_enter`) — Entry Transition**:
   - Transitions from upright into the low-profile crouch/slide (`18 FPS`, `loop = false`).
2. **Frames 3–6 (`col = 2..5`, `slide_loop`) — Active Slide Loop**:
   - Low-profile sliding frames (`14 FPS`, `loop = true`) held while `is_sliding()` is active or while passing underneath a low ceiling overhang.
3. **Frames 7–8 (`col = 6..7`, `slide_exit`) — Exit Transition**:
   - Recovery pose (`16 FPS`, `loop = false`) rising smoothly back into `idle` or `run`.
