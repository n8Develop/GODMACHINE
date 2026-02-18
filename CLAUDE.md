# GODMACHINE — Project Context

## What This Is
An autonomous AI art project. A Python orchestrator runs in a perpetual loop, calling the Anthropic API (Claude) each cycle to make ONE small change to a Godot 4.6 dungeon crawler. The game starts as an empty room with a green square. The AI adds enemies, mechanics, items, rooms, lore — forever. Every successful cycle gets a git commit and a Twitter post written in the voice of GODMACHINE, an unhinged deity building a world it doesn't fully control.

The game is never finished. The art project IS the process.

## Current State
- **Python orchestrator**: Hardened loop with tiered context, pre-validation, complexity budget, capability tracking, self-improving learnings system, and Twitter posting.
- **Lore system**: world_state.xml accumulates narrative entries each cycle (auto-compressed when >10 entries)
- **Learnings system**: AI writes technical lessons to `lore/learnings.md` each cycle, which are fed back into the prompt. The AI builds its own knowledge base over time.
- **Twitter integration**: Posts patch notes automatically after successful cycles with gameplay video (opt-in via config + env vars)
- **Strategy system**: explore / retry / pivot with domain nudges, dependency awareness, error pattern recognition, and cooldown tracking
- **Oracle system**: Expensive LLM call at end of eligible cycles — answers GODMACHINE's questions with architectural guidance
- **Whispers system**: Persistent human-editable hints in `lore/whispers.md`, injected into the prompt each cycle
- **Video recording**: Godot Movie Maker → FFmpeg AVI→MP4 → Twitter upload, with autopilot gameplay
- **Prompt caching**: System prompt cached via Anthropic API (90% input cost reduction on cached portion)
- **Exact token counting**: Pre-flight `count_tokens()` API call replaces rough `len//4` estimate

## Philosophy
- **Hands-off**: Let the LLM figure things out. Don't over-restrict its creativity.
- **Failures are art**: The process of the AI learning, failing, and adapting IS the project.
- **Validate output, don't constrain input**: Pre-validation and headless testing catch broken code. The system prompt gives the AI freedom to choose what to build.
- **Self-improving**: The learnings system lets the AI accumulate knowledge across cycles — it stops repeating the same mistakes.
- **Only GODMACHINE touches the game**: Humans modify the orchestrator. The AI modifies game/.

## Architecture

```
GODMACHINE/
├── orchestrator/           # Python — drives everything
│   ├── main.py             # Core loop: read state → call LLM → validate → test → commit/rollback
│   ├── llm.py              # Anthropic SDK wrapper, composable prompt, prompt caching, token counting
│   ├── strategy.py         # explore/retry/pivot + GameCapabilities + error pattern analysis
│   ├── cycle_logger.py     # Read/write cycle_log.xml (last ~20 entries)
│   ├── codebase_summarizer.py  # Domain classification, tiered file summarization
│   ├── godot_runner.py     # Headless testing, error parsing, pre-validation, video recording
│   ├── oracle.py           # Oracle system — expensive LLM call with distinct persona
│   ├── twitter_poster.py   # Tweepy integration — posts patch notes + video after successful cycles
│   └── config.yaml         # All settings: godot, cycle, context, validation, prompt, twitter, complexity, oracle, recording
├── game/                   # Godot 4.6 project — ONLY the AI edits this
│   ├── project.godot       # WASD input mappings, window settings, main scene, autoloads
│   ├── scenes/             # .tscn files
│   ├── scripts/            # .gd files (includes _autopilot.gd for recording)
│   └── assets/             # Sprites, sounds (currently empty — colored rectangles)
├── lore/
│   ├── world_state.xml     # Living lore document — AI reads this every cycle
│   ├── cycle_log.xml       # Rolling log of last ~20 cycle results
│   ├── cycle_archive.xml   # Archived old cycles
│   ├── learnings.md        # Self-improving knowledge — AI writes lessons, reads them back
│   ├── whispers.md         # Persistent human-editable hints injected into the prompt
│   ├── oracle_question.md  # GODMACHINE's question to the Oracle (temp, cleared after answer)
│   ├── oracle_answer.md    # Oracle's response (temp, injected into next eligible cycle)
│   └── .last_failed_diff   # Temp: git diff from last failed cycle (for retry context)
└── output/clips/           # Gameplay recordings (MP4, posted to Twitter)
```

## How the Orchestrator Loop Works
1. Read `world_state.xml`, `cycle_log.xml`, `learnings.md`, `whispers.md`, scan `game/` for codebase summary
2. **Scan capabilities** — discover existing enemies, items, rooms, mechanics, autoloads
3. Determine strategy (explore/retry/pivot) with **domain nudges**, **dependency warnings**, and **error pattern analysis**
4. Build **tiered prompt** (full source for focus domain, signatures for related, filenames for rest)
5. **Inject learnings** — accumulated technical knowledge from past cycles
6. **Inject Oracle answer** — if the Oracle responded to a previous question
7. **Inject whispers** — persistent human-editable hints from `lore/whispers.md`
8. **Token budget** — exact count via `count_tokens()` API, progressively truncate file contents if over budget
9. Call Claude via Anthropic SDK (with **prompt caching** on system prompt, model and max_tokens configurable)
10. Parse response (structured XML tags: `<action>`, `<target>`, `<files>`, `<lore_entry>`, `<patch_notes>`, `<learning>`, `<oracle_question>`)
11. **Complexity budget** — reject if >3 files, >400 lines, or >75% new files
12. Write files to disk
13. **Pre-validation** — check bracket balance, preload paths, scene ext_resource refs
14. Run `Godot --headless --quit-after N` to test
15. **Structured error parsing** — regex patterns categorize errors with actionable suggestions. Test FAILS if any errors parsed, even with exit code 0.
16. Optional **smoke test** — temp GDScript checks main scene loads + autoloads present
17. **Intent verification** — cheap Haiku call checks if code matches stated action/target
18. If PASS: git commit, update lore, **save learning**, clean up saved diff, log success, **record gameplay video**, **post to Twitter with video**
19. If FAIL: **save learning**, **save diff** for next retry, git rollback, log structured error
20. **Oracle consultation** (try/finally) — if eligible cycle and GODMACHINE asked a question, consult the Oracle
21. Sleep, repeat

## Orchestrator Module Details

### `main.py`
- Core loop with `run_cycle()` and `main()`
- `parse_response()`: extracts `<action>`, `<target>`, `<files>`, `<lore_entry>`, `<patch_notes>`, `<learning>`, `<oracle_question>`, `<curated_learnings>`
- `apply_files()`: writes LLM-generated files to disk
- `check_complexity_budget()`: rejects over-scoped changes
- `read_learnings()` / `append_learning()` / `replace_learnings()`: read/write/curate `lore/learnings.md`, auto-trims to last 50 entries
- `git_commit()` / `git_rollback()`: version control safety
- `_maybe_consult_oracle()`: runs in try/finally at cycle end, consults Oracle if eligible
- Oracle answer injection, whispers injection, curated learnings handling
- Video recording on success, Twitter posting with video (when configured)

### `codebase_summarizer.py`
- **Domain classification**: `DOMAIN_KEYWORDS` maps domains (enemies, items, rooms, core, ui) to filename keywords
- **`classify_file_domain(filepath)`**: categorizes any game file by name
- **`_extract_signatures(path)`**: pulls `extends`, `class_name`, `@export`, `func`, `signal`, `const` lines
- **`summarize_file_contents_tiered(game_path, focus_domains, edit_targets)`**: three tiers — FULL SOURCE (focus + edit targets), SIGNATURES (related domains), FILENAME ONLY (everything else)
- **`compress_world_state(xml, max_entries=10)`**: keeps last N chronicle entries verbatim, summarizes older batches of 5

### `godot_runner.py`
- **`GodotError`** dataclass: `category`, `file`, `line`, `message`, `suggestion`
- **`TestResult`** / **`RecordingResult`** dataclasses
- **`parse_godot_errors(output)`**: 6 regex patterns (parse_error, missing_node, null_access, scene_error, method_error, missing_resource)
- **`pre_validate_gdscript(path)`**: bracket/paren balancing, preload path existence
- **`validate_scene_refs(game_path, files_written)`**: checks ext_resource paths exist on disk
- **`run_smoke_test(godot_exe, project_path)`**: writes temp `_smoke_test.gd`, checks main scene + autoloads
- **`test_headless(..., quit_after=2)`**: fails if exit code != 0 OR if any errors are parsed (no silent failures)
- **`record_gameplay(...)`**: Godot Movie Maker mode with `--scene` flag. Safety: mandatory main scene detection, scene file existence check, project manager output detection (discards video if detected). Converts AVI→MP4 via FFmpeg.
- **`_detect_main_scene()`**: reads `run/main_scene` from project.godot
- **`_looks_like_project_manager()`**: scans Godot output for project manager / parse error indicators
- **`_convert_to_mp4()`**: FFmpeg AVI→H.264 MP4 (libx264, yuv420p, no audio)

### `oracle.py`
- **`consult_oracle(question, world_state, learnings, cycle_log, config)`**: Expensive LLM call with distinct persona — an ancient entity outside the loop that sees GODMACHINE's patterns
- Configurable model, max_tokens, api_timeout via `config.yaml` oracle section
- Returns Oracle's response text, written to `lore/oracle_answer.md` by main.py

### `strategy.py`
- **`GameCapabilities`** dataclass: `enemies`, `items`, `rooms`, `mechanics`, `ui_elements`, `autoloads` — with `summary()` for prompt injection
- **`scan_capabilities(game_path)`**: discovers what exists by scanning filenames, extends patterns, project.godot
- **`FEATURE_DEPENDENCIES`**: e.g. boss→enemies, shop→items, inventory→items
- **`check_dependencies(feature, capabilities)`**: returns missing prerequisites
- **Domain cooldown**: `get_recent_domains()`, `suggest_underrepresented_domain()` — nudges toward neglected domains
- **`determine_strategy(cycles, capabilities)`**: enhanced with domain nudges + dependency warnings

### `llm.py`
- **Composable system prompt**: `SYSTEM_PROMPT` (base rules + `<learning>` + `<oracle_question>` tags) + optional `FEW_SHOT_EXAMPLES` + optional `GODOT_CHEAT_SHEET` — assembled by `get_system_prompt(config)`
- **`count_tokens(messages, model, system)`**: exact token count via Anthropic `count_tokens()` API, falls back to `len//4` on error
- **`estimate_tokens(text)`**: rough `len(text) // 4` (kept for quick previews)
- **`build_cycle_prompt(...)`**: accepts `capabilities_summary`, `last_diff`, `learnings`, `oracle_context`, `oracle_available`, `whispers`, `token_budget` — progressively trims on overflow
- **`call_llm(prompt, config=config)`**: **prompt caching** on system prompt (`cache_control: ephemeral`, 90% input savings on cached portion), exact pre-flight token count, cache performance logging, retries up to 3x with exponential backoff on transient failures (429, 529, connection, timeout errors)
- **`verify_intent(action, target, files_written)`**: cheap Haiku call to check if code matches stated intent
- **First-cycle hint**: when `cycle_num == 1`, explore mode nudges the AI to start with foundational systems

### `twitter_poster.py`
- **`post_tweet(text, media_path=None)`**: posts via Twitter API v2, video via v1.1 chunked upload (`media_category="tweet_video"`)
- Text-only fallback if media upload fails; second fallback if create_tweet with media fails
- **`is_configured()`**: checks env vars are present
- Auth via env vars: `TWITTER_API_KEY`, `TWITTER_API_SECRET`, `TWITTER_ACCESS_TOKEN`, `TWITTER_ACCESS_SECRET`

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
  intent_check: true           # Cheap Haiku call to verify code matches intent
prompt:
  few_shot_examples: true      # Include example cycle in system prompt
  godot_cheat_sheet: true      # Include 4.6 API reference
  post_mortem_diff: true       # Show failed diff on retry
  model: "claude-sonnet-4-5-20250929"
  max_tokens: 8192
twitter:
  enabled: true                # Posts patch notes + video after successful cycles
recording:
  enabled: true                # Record gameplay via Godot Movie Maker after each success
  duration_seconds: 10         # How long to record
  fps: 30                      # Fixed framerate
  timeout: 30                  # Subprocess timeout
oracle:
  enabled: true                # Oracle system — answers GODMACHINE's questions
  min_cycles_between: 5        # Can only ask every N cycles
  model: "claude-sonnet-4-5-20250929"
  max_tokens: 2048
learnings:
  curate_every: 10             # Compress/deduplicate learnings every N cycles
  max_token_budget: 4000       # Advisory budget for curated learnings
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
- **Self-improving** — the learnings system lets the AI accumulate technical knowledge across cycles
- **Lore continuity** — the AI reads its own history and builds on it narratively
- **Context scaling** — tiered summarization keeps prompt size manageable as the game grows
- **Complexity gating** — budget limits prevent scope creep in LLM output

## Tech Stack
- **Python 3.12+** with `anthropic` SDK, `pyyaml`, `tweepy`, `python-dotenv`
- **Godot 4.6** (NOT 4.3 — the LLM tends to generate 4.3-era code, must be constrained)
- **GDScript** for all game code
- **FFmpeg** for AVI→MP4 video conversion (must be on PATH)
- **Git** for rollback safety
- **Godot executable**: `C:\Users\User\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`

## Environment Variables
- `ANTHROPIC_API_KEY` — required, set as persistent user env var
- `TWITTER_API_KEY` — optional, for Twitter posting
- `TWITTER_API_SECRET` — optional, for Twitter posting
- `TWITTER_ACCESS_TOKEN` — optional, for Twitter posting
- `TWITTER_ACCESS_SECRET` — optional, for Twitter posting

## Known Issues / Things to Watch
- Claude's training data is heavily Godot 4.3. The system prompt enforces 4.6 patterns (TileMapLayer not TileMap, no uid= in hand-written .tscn, format=3, etc.)
- The LLM sometimes generates too many files at once — the complexity budget rejects these (dominant failure pattern: 2 new files = 100% > 75% ratio)
- `project.godot` may be modified by the AI for input actions, autoloads, and physics layer names — but NOT display settings, main scene path, compatibility flags, or the Autopilot autoload
- The AI has previously corrupted `project.godot` syntax (missing colons in Object serialization) — this causes Godot to fall back to the project manager during recording, exposing local file paths
- The ANTHROPIC_API_KEY must be set as an environment variable (never in code/config)
- `.claude/settings.local.json` is gitignored — it contained a leaked key that was rotated
- Anthropic client is recreated every call (works but wasteful)
- Config is hot-reloaded each cycle — edit `config.yaml` while running to change settings
- The headless test error parser doesn't catch `SCRIPT ERROR:` format errors (only `res://file:line - Error:` format) — some game-breaking script errors pass silently
- `_autopilot.gd` is registered as an autoload but only activates during Movie Maker recording (`OS.has_feature("movie")`) — it's inert during normal play and headless testing

## What's Not Built Yet
- Deployment to VPS (systemd/Docker)
- Web dashboard for monitoring
- Xvfb-based headless video recording (Linux only — would eliminate project manager risk entirely)
