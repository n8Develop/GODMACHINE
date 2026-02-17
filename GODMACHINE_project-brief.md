# GODMACHINE — An AI-Driven Evolving Game Art Project

## Concept

An autonomous AI system that continuously builds and evolves a simple Diablo/Gauntlet-style top-down dungeon crawler in Godot. Every cycle, the AI reviews the current state of the game and its living lore, decides what to add or change, implements it, tests it, records a short clip, and posts it to Twitter with in-character "patch notes" written as GODMACHINE — an unhinged deity constructing a world it doesn't fully understand or control.

The game is never "finished." It grows, mutates, and accumulates history over weeks and months. The art project IS the process — the Twitter feed becomes a chronicle of an AI building a world it doesn't fully understand.

## Architecture Overview

### Core Loop (Python Orchestrator)

The system runs as a **perpetual feedback loop** — it never stops. Failure isn't a stop condition, it's just input for the next cycle. The AI learns from its own recent history and self-corrects.

```
┌─────────────────────────────────────────────────┐
│                                                   │
│  READ STATE (lore XML + codebase summary          │
│              + recent cycle log)                   │
│         │                                         │
│         ▼                                         │
│  DETERMINE STRATEGY (based on recent results)     │
│    - "explore" if last cycle succeeded             │
│    - "retry" if last cycle failed                  │
│    - "pivot" if 3+ consecutive failures            │
│         │                                         │
│         ▼                                         │
│  DECIDE (LLM picks next action given strategy)    │
│         │                                         │
│         ▼                                         │
│  ATTEMPT (generate code, apply to Godot)          │
│         │                                         │
│         ▼                                         │
│  TEST (run Godot headless)                        │
│        ╱ ╲                                        │
│       ╱   ╲                                       │
│    PASS   FAIL                                    │
│     │       │                                     │
│     ▼       ▼                                     │
│  RECORD   LOG FAILURE                             │
│  + POST   + ROLLBACK (git revert)                 │
│     │       │                                     │
│     ▼       ▼                                     │
│  LOG SUCCESS                                      │
│     │       │                                     │
│     └───┬───┘                                     │
│         │                                         │
│         ▼                                         │
│  UPDATE CONTEXT (append to cycle_log + lore XML)  │
│         │                                         │
│         ▼                                         │
│  SLEEP (configurable — every few hours or daily)  │
│         │                                         │
│         └──────────── loop back to READ ──────────┘
```

The main loop in code is simply:

```python
while True:
    run_cycle()
    time.sleep(CYCLE_INTERVAL)
```

Run as a **systemd service** or inside a **tmux/screen session** on a VPS so it persists indefinitely.

### The Cycle Log — How the AI Learns From Itself

The cycle log is a rolling record of recent attempts that the LLM sees every cycle. This gives it awareness of its own recent history so it can adapt its approach without being explicitly told to.

```xml
<recent_cycles>
  <cycle day="44" action="add_enemy" target="fire_bat" result="success"/>
  <cycle day="45" action="add_mechanic" target="wall_torches" result="fail" 
         error="Cannot find node 'TorchLight' in room_base.tscn"/>
  <cycle day="46" action="add_mechanic" target="wall_torches" result="fail"
         error="LightOccluder2D requires polygon data"/>
  <cycle day="47" action="add_mechanic" target="simpler_torch_glow" result="success"
         note="Simplified approach using PointLight2D instead"/>
</recent_cycles>
```

In the above example, the AI failed at torches twice, then simplified its approach and succeeded. Nobody told it to do that — it just had the context to figure it out.

Keep the last ~20 cycles in the log passed to the LLM. Archive older entries to a full history file.

### Adaptive Strategy Selection

The orchestrator uses simple logic to tell the LLM what mode it should be in:

```python
def determine_strategy(cycle_log):
    recent = cycle_log[-3:]  # last 3 cycles
    
    if not recent or recent[-1]["result"] == "success":
        return "explore"   # Things are working — try something new and ambitious
    
    # Count consecutive failures on the same feature
    current_target = recent[-1]["target"]
    consecutive_fails = 0
    for cycle in reversed(recent):
        if cycle["target"] == current_target and cycle["result"] == "fail":
            consecutive_fails += 1
        else:
            break
    
    if consecutive_fails >= 3:
        return "pivot"     # Abandon this feature, try something completely different
    else:
        return "retry"     # Try a different approach to the same thing
```

**Three emergent behaviors from this:**

1. **After success ("explore"):** "That worked. What should I build next?" — tends toward additive, ambitious changes. New enemies, new mechanics, new rooms.
2. **After one failure ("retry"):** "That didn't work. Let me try a different approach to the same thing." — the LLM sees the error message and adjusts.
3. **After repeated failures ("pivot"):** "I can't do this yet. Let me shelve it and try something else entirely." — prevents the AI from getting stuck in a death loop on something beyond its current ability. It can come back to it later when the codebase has evolved.

This strategy string is passed to the LLM as part of the prompt each cycle, along with the cycle log, so it knows *why* it's being asked to explore/retry/pivot.

### Tech Stack

- **Python 3.12+** — main orchestrator
- **Anthropic SDK** — LLM calls (Claude Sonnet for code generation, or whichever model works best)
- **Godot 4.x** — game engine, run via command line
- **GDScript** — all game code
- **Git** — version control for rollback safety
- **Tweepy** — Twitter API posting
- **FFmpeg** — trim/process recorded clips if needed

### Project Structure

```
godmachine/
├── orchestrator/
│   ├── main.py              # Core loop (while True: run_cycle())
│   ├── llm.py               # Anthropic API wrapper
│   ├── strategy.py           # Adaptive strategy selection (explore/retry/pivot)
│   ├── godot_runner.py       # Subprocess management for Godot (run, test, record)
│   ├── twitter_poster.py     # Tweepy integration
│   ├── lore_manager.py       # Read/write/summarize lore XML
│   ├── cycle_logger.py       # Read/write cycle log, trim to last ~20 entries
│   ├── codebase_summarizer.py # Generates concise summary of current game state for LLM context
│   └── config.yaml           # Cycle timing, API keys, paths, max retries
├── game/                     # The Godot project (this is what the AI edits)
│   ├── project.godot
│   ├── scenes/
│   │   ├── main.tscn         # Main game scene
│   │   ├── player.tscn
│   │   ├── enemies/          # One scene per enemy type
│   │   ├── rooms/            # Dungeon room templates
│   │   ├── items/            # Pickups, weapons, etc.
│   │   └── ui/               # HUD, health bars, etc.
│   ├── scripts/
│   │   ├── player.gd
│   │   ├── enemy_base.gd     # Base class all enemies extend
│   │   ├── room_generator.gd
│   │   ├── game_manager.gd   # Global state, scoring
│   │   └── ai_controller.gd  # Simple enemy AI (chase, patrol, flee)
│   └── assets/               # Sprites, sounds (start minimal — colored rectangles are fine)
├── lore/
│   ├── world_state.xml       # The living lore document
│   ├── cycle_log.xml         # Rolling log of recent cycle results (last ~20)
│   └── cycle_archive.xml     # Full history of all cycles (not sent to LLM)
└── output/
    └── clips/                # Rendered video clips before posting
```

## The Lore System (world_state.xml)

This is the AI's long-term memory. It reads this before every cycle to maintain continuity.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<world name="GODMACHINE" current_day="0">

  <chronicle>
    <!-- Each cycle appends an entry here -->
    <!-- <entry day="1" type="mechanic">Basic melee combat was forged into the world.</entry> -->
    <!-- <entry day="5" type="enemy">The Hollow Shambler emerged from the northern corridors.</entry> -->
    <!-- <entry day="12" type="event">A strange altar appeared. Its purpose is unknown.</entry> -->
  </chronicle>

  <eras>
    <!-- The AI can declare new eras when it feels a shift has occurred -->
    <!-- <era name="The Age of Silence" start_day="0" end_day="20"/> -->
  </eras>

  <factions>
    <!-- Factions that emerge organically -->
    <!-- <faction name="The Ashen Order" status="rising" introduced_day="8"/> -->
  </factions>

  <bestiary>
    <!-- Registry of all enemies the AI has created -->
    <!-- <creature name="Hollow Shambler" script="enemies/hollow_shambler.gd" introduced_day="5" behavior="chase"/> -->
  </bestiary>

  <mechanics>
    <!-- Registry of gameplay mechanics added -->
    <!-- <mechanic name="melee_combat" introduced_day="1" script="player.gd"/> -->
  </mechanics>

  <world_flags>
    <!-- Persistent flags the AI can set and check for continuity -->
    <!-- <flag key="altar_discovered" value="true" set_day="12"/> -->
  </world_flags>

</world>
```

## The Game Itself — Starting State

The initial game should be EXTREMELY minimal. The AI builds from here:

- **View:** Top-down 2D
- **Player:** A colored rectangle that moves with arrow keys
- **World:** A single room with walls
- **No enemies, no items, no mechanics** — the AI adds everything
- **Simple tilemap** using colored squares (no art assets needed at start)
- **A basic camera** that follows the player

That's it. Day 0 is an empty room with a rectangle. The whole point is watching what the AI turns it into.

## Key Design Principles

### 1. Modularity Is Everything
The AI must only edit one file/module at a time. The codebase should be structured so that adding a new enemy means creating ONE new script that extends `enemy_base.gd` and ONE new scene file — not touching 5 different files. This keeps changes isolated and reduces breakage.

### 2. Rollback Safety
Every change is a git commit. If Godot crashes after a change, the orchestrator rolls back to the last working commit and logs the failure. The AI can try a different approach next cycle.

### 3. Codebase Summarization
The full codebase will eventually be too large to fit in context. The `codebase_summarizer.py` should generate a concise markdown summary: what scripts exist, what each one does (from comments/docstrings), what enemies exist, what mechanics are active. This summary + the lore XML is what the LLM sees each cycle.

### 4. The AI Picks What To Do
Each cycle, the LLM is given the world state and codebase summary and asked to choose ONE thing to do from categories like:
- Add a new enemy type
- Add a new room layout
- Add or modify a game mechanic
- Add an item or pickup
- Trigger a lore event (something narrative that may or may not have gameplay implications)
- Improve/refactor existing code
- Add a visual effect or sound

The AI should have a bias toward additive changes (new stuff) over modifications to keep things interesting.

### 5. In-Character Patch Notes
After each successful cycle, the LLM writes a short Twitter post (under 280 chars) in the voice of GODMACHINE itself — a deity that is building a world in real time, not entirely in control, and mildly disturbed by what its creations are doing. Something like:

> "Day 34: I gave the rats fire. They were not supposed to learn fear from it. A merchant appeared near the eastern well. I did not place him there. He sells nothing. He watches. I am watching him."

A longer version can accompany the video clip as a thread or alt text.

## LLM Prompting Strategy

The orchestrator should use a system prompt that establishes:
- The AI is GODMACHINE — an all-powerful but unreliable deity constructing a world
- It should build incrementally — small, testable changes
- It must respect the existing codebase and not rewrite things unnecessarily
- It should reference and build on the lore (continuity matters)
- It should occasionally surprise itself — not every change needs to be logical
- All GDScript must be complete and runnable (no pseudocode, no placeholders)
- It should specify exactly which file(s) to create or edit

Each cycle, the user prompt should include:
1. The **current strategy** ("explore", "retry", or "pivot") with an explanation
2. The **recent cycle log** (last ~20 entries) so the AI can see what it recently tried and what happened
3. The **world state XML** (lore, factions, bestiary, mechanics)
4. The **codebase summary** (what scripts exist, what they do)
5. A clear instruction like: "You are in EXPLORE mode. Choose one thing to add to the world. Output the exact file path and complete file contents."

For **retry mode**, also include the specific error message from the last attempt.
For **pivot mode**, explicitly tell the LLM: "Your last 3 attempts at [feature] failed. Abandon it for now and try something completely different."

## Recording Gameplay Clips

Godot 4 has a built-in Movie Maker mode (`--write-movie`) that can render frames to a video file. The orchestrator should:
1. Launch the game with movie recording enabled
2. Let it run for 10-15 seconds (the player can be AI-controlled for the recording, just wandering around so we see the world)
3. Stop Godot
4. Optionally trim/compress with FFmpeg
5. Output to `output/clips/day_XXX.mp4`

For the gameplay recording, an "autopilot" script should control the player — moving randomly, attacking if enemies are near — so the clips show the world in action without human input.

## What To Build First (Suggested Order)

1. **The Godot skeleton** — empty room, player rectangle, movement, camera
2. **The orchestrator loop** — hardcode a single cycle, no LLM yet, just prove Godot runs headless and produces a clip
3. **LLM integration** — connect Anthropic SDK, have it generate its first change
4. **Test/rollback system** — git integration, crash detection, retry logic
5. **Cycle log + strategy system** — log each cycle result, implement explore/retry/pivot logic
6. **Lore system** — XML read/write, pass to LLM each cycle
7. **Codebase summarizer** — scan game/ directory, produce markdown summary
8. **Twitter integration** — Tweepy setup, media upload, posting
9. **Autopilot recorder** — AI-controlled player for clip capture
10. **Scheduling** — run as a systemd service or tmux session, configure cycle interval
11. **Let it run and never touch it again**

## Deployment — Running It Forever

The orchestrator should run as a persistent process on a VPS (Hetzner, DigitalOcean, etc.). Options:

- **systemd service** (recommended) — auto-restarts on crash, starts on boot, logs to journald
- **tmux/screen session** — simpler for development, but no auto-restart
- **Docker container** — cleanest isolation, Godot + Python + FFmpeg all in one image

Requirements for the VPS:
- Godot 4.x installed (headless export template for Linux)
- Python 3.12+
- Git
- FFmpeg
- Enough RAM for Godot to render (~2-4GB should be fine for a 2D game)
- No GPU required — this is a simple 2D project

The orchestrator should also handle its own crashes gracefully — wrap `run_cycle()` in a try/except that logs the error and continues to the next cycle rather than dying.

```python
while True:
    try:
        run_cycle()
    except Exception as e:
        log_error(f"Cycle crashed: {e}")
        # Don't die — just sleep and try again
    time.sleep(CYCLE_INTERVAL)
```

## Open Questions / Things To Decide During Planning

- What's the ideal cycle frequency? (Every 2 hours? Every 6 hours? Daily?)
- Should there be any human approval step before posting, or fully autonomous?
- Should the AI be allowed to create/use simple sprite art (e.g., pixel art via code), or keep everything as colored shapes?
- How to handle the context window as the codebase grows — summarization depth vs. accuracy tradeoff
- Should the game be playable by humans via an itch.io build, or is it purely a spectator experience via Twitter?
- Do we want a simple web dashboard to monitor the AI's activity and lore state?
