# GODMACHINE — Project Context

## What This Is
An autonomous AI art project. A Python orchestrator runs in a perpetual loop, calling the Anthropic API (Claude) each cycle to make ONE small change to a Godot 4.6 dungeon crawler. The game starts as an empty room with a green square. The AI adds enemies, mechanics, items, rooms, lore — forever. Every successful cycle gets a git commit and eventually a Twitter post written in the voice of GODMACHINE, an unhinged deity building a world it doesn't fully control.

The game is never finished. The art project IS the process.

## Current State (as of Step 2 complete)
- **Godot skeleton**: Working top-down 2D game with player movement (WASD), shooting (IJKL), walled room, camera follow
- **Python orchestrator**: Functional loop that calls Claude API → applies code → tests headless → commits or rolls back
- **5 successful AI cycles have run**, adding: Watcher enemies, projectile system, health pickups, door/room transitions, cursed shrine
- **Lore system**: world_state.xml accumulates narrative entries each cycle
- **Strategy system**: explore (after success) / retry (after failure) / pivot (after 3+ failures on same thing)

## Architecture

```
GODMACHINE/
├── orchestrator/           # Python — drives everything
│   ├── main.py             # Core loop: read state → call LLM → apply → test → commit/rollback
│   ├── llm.py              # Anthropic SDK wrapper, system prompt, prompt builder
│   ├── strategy.py         # explore/retry/pivot logic
│   ├── cycle_logger.py     # Read/write cycle_log.xml (last ~20 entries)
│   ├── codebase_summarizer.py  # Scans game/ to build context for LLM
│   ├── godot_runner.py     # Runs Godot headless to test changes
│   └── config.yaml         # Godot path, cycle timing, file paths
├── game/                   # Godot 4.6 project — the AI edits this
│   ├── project.godot
│   ├── scenes/             # .tscn files (main, player, enemies, rooms, items, UI)
│   ├── scripts/            # .gd files (all GDScript)
│   └── assets/             # Sprites, sounds (currently empty — colored rectangles)
├── lore/
│   ├── world_state.xml     # Living lore document — AI reads this every cycle
│   ├── cycle_log.xml       # Rolling log of last ~20 cycle results
│   └── cycle_archive.xml   # Archived old cycles
└── output/clips/           # For future video recording
```

## How the Orchestrator Loop Works
1. Read `world_state.xml`, `cycle_log.xml`, scan `game/` for codebase summary
2. Determine strategy (explore/retry/pivot) from recent cycle history
3. Build prompt with all context, call Claude via Anthropic SDK
4. Parse response (structured XML tags: `<action>`, `<target>`, `<files>`, `<lore_entry>`, `<patch_notes>`)
5. Write files to disk
6. Run `Godot --headless --quit-after 2` to test
7. If PASS: git commit, update lore, log success
8. If FAIL: git rollback (checkout + clean), log failure with error
9. Sleep, repeat

## Key Design Principles
- **One change per cycle** — small, testable, isolated
- **Modularity** — new enemies/items/rooms are self-contained files, not edits to core systems
- **Rollback safety** — every change is tested before committing; failures revert cleanly
- **Failure is input** — the AI sees its own error messages and adapts
- **Lore continuity** — the AI reads its own history and builds on it narratively

## Tech Stack
- **Python 3.12+** with `anthropic` SDK
- **Godot 4.6** (NOT 4.3 — the LLM tends to generate 4.3-era code, must be constrained)
- **GDScript** for all game code
- **Git** for rollback safety
- **Godot executable**: `C:\Users\User\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`

## Known Issues / Things to Watch
- Claude's training data is heavily Godot 4.3. The system prompt must enforce 4.6 patterns (TileMapLayer not TileMap, no uid= in hand-written .tscn, format=3, etc.)
- The LLM sometimes generates too many files at once or rewrites core files unnecessarily. The prompt tells it to prefer new files over edits.
- `project.godot` should rarely be modified by the AI — only for new input actions.
- The ANTHROPIC_API_KEY must be set as an environment variable (never in code/config).

## What's Not Built Yet
- Twitter posting (Tweepy integration)
- Video recording (Godot Movie Maker + FFmpeg)
- Autopilot player for recordings
- Codebase summarization depth control (will matter as game grows)
- Deployment to VPS (systemd/Docker)
- Web dashboard for monitoring
