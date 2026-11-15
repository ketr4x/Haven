# Art & Main Menu (`art-mainmenu`)

Documentation of all main menu artwork, animation, font, UI, and state-flow changes implemented on branch `feature/main-menu`.

## 1. Animated Sprite Sheet & Rendering

- **Asset**: `assets/art/main_menu_sheet.png` (`1584 × 192` px, `32bpp RGBA`, authored in the Luap-40 palette).
- **Grid**: `11` columns × `2` rows, each frame `144 × 96` px.
  - **Row 0 (`idle`)**: 11 looping frames (`y = 0`, `x = 0..1440`), played at `4.0 FPS` (`loop = true`).
  - **Row 1 (`outro`)**: 8 one-shot frames (`y = 96`, `x = 0..1008`), played at `6.0 FPS` (`loop = false`) when starting a match.
- **Pixel-crisp display**:
  - Rendered via `AnimatedSprite2D` (`BackgroundSprite`) with `texture_filter = Nearest` (`1`) and `centered = false`.
  - `_update_background_layout()` scales the `144 × 96` artwork using top-aligned cover scaling (`cover_scale = maxf(size.x / 144.0, size.y / 96.0)`, centered horizontally, `y = 0.0`) so it fills the full `1280 × 720` viewport with no black bars while keeping the upper `REZONANS` logo, moon, and animated character completely uncropped.
- **Luap-40 Post-Process Bypass on Menu**:
  - Because `assets/art/main_menu_sheet.png` is already authored in the exact Luap-40 palette, `scripts/game/race.gd` disables `Luap40PostProcess` during `RaceState.TITLE` and `RaceState.STARTING` and re-enables it for `COUNTDOWN`, `RACING`, `PAUSED`, and `FINISHED`.

## 2. Fonts

- **Default UI Font**: `assets/fonts/runescape_uf.ttf`, wrapped in `assets/fonts/default_font.tres` (`FontVariation` with `assets/fonts/kiwi_soda.ttf` configured as fallback for Polish diacritics `Ą Ć Ę Ł Ń Ó Ś Ź Ż`).
- **Project Configuration**: `project.godot` sets `[gui] theme/custom_font="res://assets/fonts/default_font.tres"`.
- **Accent Font (`assets/fonts/kiwi_soda.ttf`)**: Reserved strictly for special emphasis in `scenes/game/race.tscn` (`Countdown`, `PausePanel/Title`, and `ResultPanel/Winner`). All standard HUD labels, timers, menu items, hints, and result details inherit `runescape_uf.ttf`.

## 3. Frameless Retro Menu UI & Copy

- **Scene & Script**: `scenes/game/main_menu.tscn` and `scripts/game/main_menu.gd` (`class_name MainMenu`), instanced as `GlobalUi/TitlePanel` in `scenes/game/race.tscn`.
- **No boxes / no standard buttons**:
  - Menu items are frameless retro text rows (`MenuOverlay/MenuItems/PlayOption` and `QuitOption`), each built as an `HBoxContainer` with a fixed-width `Cursor` (`>`) and `Text` (`GRAJ` / `WYJDŹ`), styled with crisp white (`#f5f5f5` selected, `#bfbfbf` unselected), pixel outlines, and drop shadows.
  - Positioned in the mid-left below the artwork logo (`offset_left = 72`, `offset_top = 348`).
- **Bottom Copy**:
  - Controls prompt (`MenuOverlay/Prompt`, white `#f5f5f5`): `"STRZAŁKI / W S  WYBÓR      ENTER / SPACJA  ZATWIERDŹ"`
  - Gameplay tip (`MenuOverlay/Hint`, white `#f5f5f5`): `"Odbijaj fale dźwiękowe, aby zobaczyć otoczenie!"`
  - Player-specific control blocks and any `"WYŚCIG ECHA"` / old boost-tip copy were removed.

## 4. Navigation, Retro Pixel Transition & Verification

- **Menu Input (`MainMenu.handle_menu_input`)**:
  - `ui_up` / `p1_jump` (`W`) / `p2_jump` (`Up`) and `ui_down` / `p1_shout` (`S`) / `p2_shout` (`Down`) move selection between `GRAJ` and `WYJDŹ`.
  - `ui_accept` (`Enter` / `Space`) or left mouse click activates the selected option (`start_requested` or `quit_requested`).
  - Mouse hover updates selection.
- **Retro Pixel Transition (`assets/shaders/retro_pixel_transition.gdshader`)**:
  - `scenes/game/race.tscn` includes `TransitionLayer/TransitionRect` (`CanvasLayer` at `layer = 101`) using an `8×8` pixel-block 4×4 Bayer ordered-dither dissolve to solid black (`#000000`).
  - `RaceState.STARTING` triggers `MainMenu.play_outro()`, hiding `MenuOverlay` and playing the 8-frame `outro` animation.
  - On `outro_finished`, `race.gd` tweens the dithered pixel dissolve to full black (`pixel_transition_half_duration = 0.45s`), swaps `TitlePanel` to `RaceState.COUNTDOWN` (`countdown_started`) unseen at full black, holds briefly (`0.08s`), and dissolves back out to reveal the split-screen race and `3, 2, 1` countdown (`transition_finished`).
  - `_restart_course()` cancels any active transition, returns to `RaceState.TITLE`, and resets `MainMenu` back to the `idle` loop.
- **Tests (`tests/race_shell_check.gd`)**:
  - Verifies 11 `idle` frames, 8 `outro` frames, arrow-key navigation (`ui_down` / `ui_up`), `ui_accept` triggering `outro` and hiding `MenuOverlay`, non-instant pixelated transition (`TransitionRect` active after `outro_finished`), `countdown_started` hiding `TitlePanel`, and `transition_finished` hiding `TransitionRect`.
