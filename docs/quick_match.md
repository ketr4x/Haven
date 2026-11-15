# Quick Match

`GRA ONLINE` → `SZYBKI MECZ` now starts a public two-player quick-match search.

## Flow

1. The client connects through `OnlineService`.
2. `OnlineMatch` requests public GD-Sync lobbies.
3. It considers only open lobbies with exactly one player, a two-player limit, `mode = quick_race`, and the current protocol version.
4. If a compatible lobby exists, it selects one randomly and joins it as Player 2.
5. If no compatible lobby exists, it creates an open two-player lobby and becomes Player 1.
6. A join collision refreshes the public lobby list and retries once. A second failure returns an online error result.
7. Once paired, quick match uses the same seed, signature, countdown, finish, and disconnect flow as a private friend room.

Quick match is intentionally not skill-based. It has no region selection, persistent queue, bot, rating, or reconnection support. The menu provides Escape to cancel while searching.

## Test coverage

`tests/quick_match_check.gd` verifies that an empty public list creates a correctly tagged public lobby, while an existing compatible lobby is joined rather than replaced.
