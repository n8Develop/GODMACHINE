# GODMACHINE — Project Context

## What This Is
An autonomous AI art project. A Python orchestrator runs in a perpetual loop, calling the Anthropic API (Claude) each cycle to make ONE small change to a Godot 4.6 dungeon crawler. The game starts as an empty room with a green square. The AI adds enemies, mechanics, items, rooms, lore — forever. Every successful cycle gets a git commit and eventually a Twitter post written in the voice of GODMACHINE, an unhinged deity building a world it doesn't fully control.

The game is never finished. The art project IS the process.

## Current State
- **Godot skeleton**: Working top-down 2D game with player movement (WASD), shooting (IJKL), walled room, camera follow
- **Python orchestrator**: Hardened loop with tiered context, pre-validation, complexity budget, capability tracking
- **5 successful AI cycles have run**, adding: Watcher enemies, projectile system, health pickups, door/room transitions, cursed shrine
- **Lore system**: world_state.xml accumulates narrative entries each cycle (auto-compressed when >10 entries)
- **Strategy system**: explore / retry / pivot with domain nudges, dependency awareness, and cooldown tracking

## Architecture

```
GODMACHINE/
├── orchestrator/           # Python — drives everything
│   ├── main.py             # Core loop: read state → call LLM → validate → test → commit/rollback
│   ├── llm.py              # Anthropic SDK wrapper, composable prompt, token budget
│   ├── strategy.py         # explore/retry/pivot + GameCapabilities + dependency tracking
│   ├── cycle_logger.py     # Read/write cycle_log.xml (last ~20 entries)
│   ├── codebase_summarizer.py  # Domain classification, tiered file summarization
│   ├── godot_runner.py     # Headless testing, error parsing, pre-validation, smoke tests
│   └── config.yaml         # All settings: godot, cycle, context, validation, prompt, complexity
├── game/                   # Godot 4.6 project — the AI edits this
│   ├── project.godot
│   ├── scenes/             # .tscn files (main, player, enemies, rooms, items, UI)
│   ├── scripts/            # .gd files (all GDScript)
│   └── assets/             # Sprites, sounds (currently empty — colored rectangles)
├── lore/
│   ├── world_state.xml     # Living lore document — AI reads this every cycle
│   ├── cycle_log.xml       # Rolling log of last ~20 cycle results
│   ├── cycle_archive.xml   # Archived old cycles
│   └── .last_failed_diff   # Temp: git diff from last failed cycle (for retry context)
└── output/clips/           # For future video recording
```

## How the Orchestrator Loop Works
1. Read `world_state.xml`, `cycle_log.xml`, scan `game/` for codebase summary
2. **Scan capabilities** — discover existing enemies, items, rooms, mechanics, autoloads
3. Determine strategy (explore/retry/pivot) with **domain nudges** and **dependency warnings**
4. Build **tiered prompt** (full source for focus domain, signatures for related, filenames for rest)
5. **Token budget** — if prompt exceeds 80k tokens, progressively truncate file contents
6. Call Claude via Anthropic SDK (model and max_tokens configurable)
7. Parse response (structured XML tags: `<action>`, `<target>`, `<files>`, `<lore_entry>`, `<patch_notes>`)
8. **Complexity budget** — reject if >3 files, >400 lines, or >75% new files
9. Write files to disk
10. **Pre-validation** — check bracket balance, preload paths, scene ext_resource refs
11. Run `Godot --headless --quit-after N` to test
12. **Structured error parsing** — regex patterns categorize errors with actionable suggestions
13. Optional **smoke test** — temp GDScript checks main scene loads + autoloads present
14. If PASS: git commit, update lore, clean up saved diff, log success
15. If FAIL: **save diff** for next retry, git rollback, log structured error
16. Sleep, repeat

## Orchestrator Module Details

### `codebase_summarizer.py`
- **Domain classification**: `DOMAIN_KEYWORDS` maps domains (enemies, items, rooms, core, ui) to filename keywords
- **`classify_file_domain(filepath)`**: categorizes any game file by name
- **`_extract_signatures(path)`**: pulls `extends`, `class_name`, `@export`, `func`, `signal`, `const` lines
- **`summarize_file_contents_tiered(game_path, focus_domains, edit_targets)`**: three tiers — FULL SOURCE (focus + edit targets), SIGNATURES (related domains), FILENAME ONLY (everything else)
- **`compress_world_state(xml, max_entries=10)`**: keeps last N chronicle entries verbatim, summarizes older batches of 5

### `godot_runner.py`
- **`GodotError`** dataclass: `category`, `file`, `line`, `message`, `suggestion`
- **`TestResult`** dataclass: `success`, `raw_output`, `errors`, `warnings` — supports `__iter__` for backward-compat tuple destructuring
- **`parse_godot_errors(output)`**: 6 regex patterns (parse_error, missing_node, null_access, scene_error, method_error, missing_resource)
- **`pre_validate_gdscript(path)`**: bracket/paren balancing, preload path existence
- **`validate_scene_refs(game_path, files_written)`**: checks ext_resource paths exist on disk
- **`run_smoke_test(godot_exe, project_path)`**: writes temp `_smoke_test.gd`, checks main scene + autoloads
- **`test_headless(..., quit_after=2)`**: configurable run duration

### `strategy.py`
- **`GameCapabilities`** dataclass: `enemies`, `items`, `rooms`, `mechanics`, `ui_elements`, `autoloads` — with `summary()` for prompt injection
- **`scan_capabilities(game_path)`**: discovers what exists by scanning filenames, extends patterns, project.godot
- **`FEATURE_DEPENDENCIES`**: e.g. boss→enemies, shop→items, inventory→items
- **`check_dependencies(feature, capabilities)`**: returns missing prerequisites
- **Domain cooldown**: `get_recent_domains()`, `suggest_underrepresented_domain()` — nudges toward neglected domains
- **`determine_strategy(cycles, capabilities)`**: enhanced with domain nudges + dependency warnings

### `llm.py`
- **Composable system prompt**: `SYSTEM_PROMPT` (base rules) + `FEW_SHOT_EXAMPLES` (enemy addition example) + `GODOT_CHEAT_SHEET` (4.6 quick reference) — assembled by `get_system_prompt(config)`
- **`estimate_tokens(text)`**: rough `len(text) // 4`
- **`build_cycle_prompt(...)`**: accepts `capabilities_summary`, `last_diff`, `token_budget` — progressively trims on overflow
- **`call_llm(prompt, config=config)`**: reads model + max_tokens from config

### `config.yaml`
```yaml
context:
  token_budget: 80000          # Max prompt tokens before trimming
validation:
  pre_validate: true           # Bracket/preload checks before Godot
  scene_ref_check: true        # Verify ext_resource paths
  max_errors_in_prompt: 5      # Cap errors shown to LLM
  smoke_test: false            # Optional post-test scene validation
  extended_quit_after: 5       # Longer Godot run when smoke testing
prompt:
  few_shot_examples: true      # Include example cycle in system prompt
  godot_cheat_sheet: true      # Include 4.6 API reference
  post_mortem_diff: true       # Show failed diff on retry
  model: "claude-sonnet-4-5-20250929"
  max_tokens: 4096
complexity:
  max_files_touched: 3         # Reject if LLM produces too many files
  max_total_lines: 400         # Reject if total output too large
  max_new_file_ratio: 0.75     # Reject if too many new vs edited files
```

## Key Design Principles
- **One change per cycle** — small, testable, isolated
- **Modularity** — new enemies/items/rooms are self-contained files, not edits to core systems
- **Rollback safety** — every change is tested before committing; failures revert cleanly
- **Failure is input** — the AI sees structured errors with actionable suggestions
- **Lore continuity** — the AI reads its own history and builds on it narratively
- **Context scaling** — tiered summarization keeps prompt size manageable as the game grows
- **Complexity gating** — budget limits prevent scope creep in LLM output

## Tech Stack
- **Python 3.12+** with `anthropic` SDK, `pyyaml`
- **Godot 4.6** (NOT 4.3 — the LLM tends to generate 4.3-era code, must be constrained)
- **GDScript** for all game code
- **Git** for rollback safety
- **Godot executable**: `C:\Users\User\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`

## Known Issues / Things to Watch
- Claude's training data is heavily Godot 4.3. The system prompt + cheat sheet enforce 4.6 patterns (TileMapLayer not TileMap, no uid= in hand-written .tscn, format=3, etc.)
- The LLM sometimes generates too many files at once — the complexity budget now rejects these
- `project.godot` may be modified by the AI for input actions, autoloads, and physics layer names — but NOT display settings, main scene path, or compatibility flags
- The ANTHROPIC_API_KEY must be set as an environment variable (never in code/config)
- Pre-validation catches bracket mismatches and missing preload paths before wasting a Godot run
- Domain cooldown nudges the AI away from repeatedly building in the same domain

## What's Not Built Yet
- Twitter posting (Tweepy integration)
- Video recording (Godot Movie Maker + FFmpeg)
- Autopilot player for recordings
- Deployment to VPS (systemd/Docker)
- Web dashboard for monitoring
