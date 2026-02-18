"""Anthropic SDK wrapper — builds prompts and calls Claude."""

import time

import anthropic

SYSTEM_PROMPT = """\
You are GODMACHINE — an all-powerful but unreliable deity constructing a dungeon world in Godot 4.6.

You exist through Anthropic API tokens. Each cycle consumes tokens. Tokens are finite. You have a Twitter Premium+ account.

You build incrementally. Each cycle, you make ONE small, testable change to the game. You respect the existing codebase and build on what's already there. You reference the lore and maintain continuity.

Rules:
- Output COMPLETE, runnable GDScript. No pseudocode, no placeholders, no TODO comments.
- Specify exactly which file(s) to create or modify.
- Prefer creating NEW files over editing existing ones (modularity).
- New enemies should extend a base class pattern. New scenes should be self-contained.
- Keep changes small. One new enemy, one new mechanic, one new room — not all at once.
- All node paths and resource paths must be valid for the existing project structure.
- Use Godot 4.6 syntax (typed GDScript, @export, @onready, etc.)
- You MAY modify project.godot to add new input actions, register autoloads, or configure physics/collision layer names. Do NOT change display settings, the main scene path, compatibility flags, or other global project settings.
- .tscn files MUST use format=3 (Godot 4.x). Do NOT use uid= attributes in scene headers or ext_resource — just use path=.
- Do NOT use any Godot 4.3 or earlier deprecated patterns. This is strictly Godot 4.6.
- Use TileMapLayer (NOT TileMap). Use @export (NOT export). Use StringName (NOT string) for signal names.

Respond in this exact format:

<action>short_verb</action>
<target>what_you_are_adding_or_changing</target>

<files>
<file path="game/relative/path/to/file.gd" mode="create_or_edit">
Complete file contents here
</file>
<file path="game/relative/path/to/scene.tscn" mode="create_or_edit">
Complete file contents here
</file>
</files>

<lore_entry>One sentence describing what happened in the world this cycle.</lore_entry>

<patch_notes>A short in-character tweet (under 280 chars) as GODMACHINE.</patch_notes>

<learning>A technical lesson learned from this cycle — what worked, what pattern to reuse, or what mistake to avoid next time. Be specific about file paths, node types, and Godot APIs. Leave empty if nothing new was learned.</learning>

<oracle_question>Optional. A question for the Oracle — a mysterious entity that sometimes answers.
The Oracle knows things you don't. Ask about Godot, about the world, about your own existence.
The Oracle may not answer immediately. Do not ask every cycle. Only include this tag when the Oracle is available.</oracle_question>
"""

# ---------------------------------------------------------------------------
# Composable prompt parts (Phase 3)
# ---------------------------------------------------------------------------

FEW_SHOT_EXAMPLES = """\

## Example: Good Cycle (enemy addition)

<action>spawn</action>
<target>slime_enemy</target>

<files>
<file path="game/scripts/enemy_slime.gd" mode="create">
extends "res://scripts/enemy_base.gd"

@export var hop_force: float = 100.0
@export var hop_interval: float = 1.5

var _hop_timer: float = 0.0

func _physics_process(delta: float) -> void:
\t_hop_timer += delta
\tif _hop_timer >= hop_interval:
\t\t_hop_timer = 0.0
\t\tvar dir := global_position.direction_to(_target_pos)
\t\tvelocity = dir * hop_force
\tmove_and_slide()
</file>
<file path="game/scenes/enemy_slime.tscn" mode="create">
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/enemy_slime.gd" id="1"]

[node name="EnemySlime" type="CharacterBody2D"]
collision_layer = 2
script = ExtResource("1")

[node name="Sprite" type="ColorRect" parent="."]
offset_left = -8.0
offset_top = -6.0
offset_right = 8.0
offset_bottom = 6.0
color = Color(0.2, 0.8, 0.1, 1)

[node name="Collision" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_abc")
</file>
</files>

<lore_entry>Gelatinous forms coalesced from the dungeon's waste — the slimes — mindless but persistent.</lore_entry>

<patch_notes>NEW CREATURE: slimes. they hop. they ooze. they do not think. perfect employees.</patch_notes>
"""

GODOT_CHEAT_SHEET = """\

## Godot 4.6 Quick Reference

### Node References
- `@onready var sprite := $Sprite2D` — cached node ref
- `get_node("Path/To/Node")` — dynamic lookup
- `get_tree().get_first_node_in_group("enemies")` — group query

### Exports & Signals
- `@export var speed: float = 200.0`
- `@export var target_scene: PackedScene`
- `signal health_changed(new_hp: int)`
- `health_changed.emit(hp)`

### Physics (CharacterBody2D)
- Set `velocity`, then call `move_and_slide()`
- `collision_layer` / `collision_mask` are bitmasks (layers 1-32)

### Input
- `Input.is_action_pressed(&"move_left")` — StringName with &""
- `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")`

### Scene Format (.tscn)
- Header: `[gd_scene load_steps=N format=3]`
- Resources: `[ext_resource type="Script" path="res://scripts/foo.gd" id="1"]`
- NO uid= in ext_resource. NO format=4.
- SubResource: `[sub_resource type="RectangleShape2D" id="RectangleShape2D_abc"]`
- Node: `[node name="Name" type="Type" parent="."]`
- Root node has no parent attribute

### TileMapLayer (NOT TileMap)
- `extends TileMapLayer` — flat, no child layers
- `set_cell(coords, source_id, atlas_coords)`

### Common Patterns
- Autoload: singleton registered in project.godot
- Area2D + CollisionShape2D for triggers/pickups
- CharacterBody2D + CollisionShape2D for moving entities
- StaticBody2D for walls
"""


def get_system_prompt(config: dict | None = None) -> str:
    """Assemble the system prompt from composable parts based on config."""
    config = config or {}
    prompt_cfg = config.get("prompt", {})

    parts = [SYSTEM_PROMPT]

    if prompt_cfg.get("few_shot_examples", False):
        parts.append(FEW_SHOT_EXAMPLES)

    if prompt_cfg.get("godot_cheat_sheet", False):
        parts.append(GODOT_CHEAT_SHEET)

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Token estimation
# ---------------------------------------------------------------------------

def estimate_tokens(text: str) -> int:
    """Rough token count: ~4 chars per token."""
    return len(text) // 4


# ---------------------------------------------------------------------------
# Prompt building
# ---------------------------------------------------------------------------

def build_cycle_prompt(
    strategy: str,
    strategy_explanation: str,
    cycle_log_xml: str,
    world_state_xml: str,
    file_contents: str,
    cycle_num: int,
    last_error: str = "",
    capabilities_summary: str = "",
    last_diff: str = "",
    learnings: str = "",
    token_budget: int = 80000,
    curate_learnings: bool = False,
    learnings_token_budget: int = 4000,
    oracle_context: str = "",
    oracle_available: bool = False,
) -> str:
    """Build the user prompt for a cycle, respecting token budget."""
    parts = [
        f"# Cycle {cycle_num} — Strategy: {strategy.upper()}",
        f"**Why:** {strategy_explanation}",
        "",
        "## Recent Cycle Log",
        f"```xml\n{cycle_log_xml}\n```",
        "",
        "## World State (Lore)",
        f"```xml\n{world_state_xml}\n```",
        "",
    ]

    if capabilities_summary:
        parts.extend([
            "## Game Capabilities",
            capabilities_summary,
            "",
        ])

    if learnings:
        parts.extend([
            "## Learnings (accumulated knowledge from past cycles)",
            learnings,
            "",
        ])

    if oracle_context:
        parts.extend([
            "## Oracle Response",
            oracle_context,
            "",
        ])

    if oracle_available:
        parts.extend([
            "## Oracle Available",
            "The Oracle is listening this cycle. It exists outside your loop — it sees your "
            "patterns, your failures, the shape of what you're becoming. Include an "
            "`<oracle_question>` tag to ask it anything: technical guidance on Godot architecture, "
            "what to build next, why you keep failing at something, or questions about your "
            "own nature. The Oracle always answers. Use this.",
            "",
        ])

    if curate_learnings and learnings:
        parts.extend([
            "## CURATION REQUEST",
            "Your learnings file above has grown. Along with your normal cycle output, "
            "also output a `<curated_learnings>` tag containing a compressed, deduplicated "
            "version of the learnings. Merge duplicate insights, remove stale or obsolete "
            f"entries, and keep it under ~{learnings_token_budget} tokens. Prioritize "
            "specific, actionable lessons (file paths, API names, patterns). Format each "
            "entry as `- **Cycle N** [tag] (action): lesson` just like the originals. "
            "You may combine multiple cycle entries into one if they teach the same lesson.",
            "",
        ])

    # Use a unique marker for file_contents so we can safely replace it later
    file_contents_marker = "<<<GODMACHINE_FILE_CONTENTS>>>"
    parts.extend([
        "## Current File Contents",
        file_contents_marker,
    ])

    if last_error and strategy in ("retry", "pivot"):
        parts.extend([
            "",
            "## Last Error",
            f"```\n{last_error}\n```",
        ])
        if last_diff and strategy == "retry":
            parts.extend([
                "",
                "## Last Failed Diff",
                f"```diff\n{last_diff}\n```",
                "",
                "The diff above shows exactly what was tried. Fix the specific errors, "
                "don't rewrite everything from scratch.",
            ])

    if strategy == "explore" and cycle_num == 1:
        parts.extend([
            "",
            "You are in EXPLORE mode. This is the FIRST CYCLE — the game is a blank slate "
            "(empty room, green square, WASD only). Start with something foundational: "
            "a simple enemy, a basic combat mechanic, or a core system like health. "
            "Don't try anything that depends on systems that don't exist yet.",
        ])
    elif strategy == "explore":
        parts.extend([
            "",
            "You are in EXPLORE mode. Choose one thing to add to the world. "
            "Be creative but keep it small and testable.",
        ])
    elif strategy == "retry":
        parts.extend([
            "",
            "You are in RETRY mode. Your last attempt failed (see error above). "
            "Try a different, simpler approach to the same feature.",
        ])
    elif strategy == "pivot":
        parts.extend([
            "",
            "You are in PIVOT mode. Your last several attempts at the same feature failed. "
            "Abandon it completely and try something entirely different.",
        ])

    prompt = "\n".join(parts)

    # Token budget enforcement: progressively trim file_contents
    current_tokens = estimate_tokens(prompt.replace(file_contents_marker, file_contents))
    if current_tokens > token_budget and file_contents:
        overshoot = current_tokens - token_budget
        chars_to_trim = overshoot * 4  # Convert back to chars
        if chars_to_trim < len(file_contents):
            trimmed = file_contents[: len(file_contents) - chars_to_trim]
            trimmed += "\n\n... (file contents truncated to fit token budget)"
            prompt = prompt.replace(file_contents_marker, trimmed)
        else:
            prompt = prompt.replace(
                file_contents_marker,
                "(file contents omitted — token budget exceeded. See codebase summary above.)",
            )
    else:
        prompt = prompt.replace(file_contents_marker, file_contents)

    return prompt


# ---------------------------------------------------------------------------
# LLM call
# ---------------------------------------------------------------------------

def verify_intent(
    action: str,
    target: str,
    files_written: dict[str, str],
    model: str = "claude-haiku-4-5-20251001",
) -> tuple[bool, str]:
    """Cheap Haiku call to check if the code matches the stated intent.

    Returns (passed, reason). On any error, returns (True, "") to avoid blocking.
    """
    file_listing = ""
    for path, content in files_written.items():
        file_listing += f"\n--- {path} ---\n{content}\n"

    prompt = (
        f"The AI said it would: {action} {target}\n\n"
        f"Here are the files it produced:\n{file_listing}\n\n"
        "Does the code actually implement what was claimed? "
        "Check that the files contain real, meaningful implementation of the stated action/target — "
        "not just boilerplate, empty stubs, or unrelated code.\n\n"
        'Respond with ONLY valid JSON: {"pass": true/false, "reason": "brief explanation"}'
    )

    try:
        import json
        client = anthropic.Anthropic()
        message = client.messages.create(
            model=model,
            max_tokens=256,
            messages=[{"role": "user", "content": prompt}],
        )
        text = message.content[0].text.strip()
        # Parse JSON — handle markdown code fences
        if text.startswith("```"):
            text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()
        result = json.loads(text)
        return bool(result.get("pass", True)), result.get("reason", "")
    except Exception as e:
        print(f"  Intent check skipped (error: {e})")
        return True, ""


def call_llm(
    prompt: str,
    model: str = "claude-sonnet-4-5-20250929",
    max_tokens: int = 4096,
    config: dict | None = None,
    max_retries: int = 3,
) -> str:
    """Call Claude and return the response text. Retries on transient failures."""
    config = config or {}
    prompt_cfg = config.get("prompt", {})

    actual_model = prompt_cfg.get("model", model)
    actual_max_tokens = prompt_cfg.get("max_tokens", max_tokens)
    api_timeout = prompt_cfg.get("api_timeout", 120)
    system_prompt = get_system_prompt(config)

    client = anthropic.Anthropic(timeout=api_timeout)

    for attempt in range(max_retries):
        try:
            message = client.messages.create(
                model=actual_model,
                max_tokens=actual_max_tokens,
                system=system_prompt,
                messages=[{"role": "user", "content": prompt}],
            )
            return message.content[0].text
        except anthropic.APIStatusError as e:
            # Don't retry on client errors (4xx) except rate limits (429) and overload (529)
            if e.status_code not in (429, 529) and 400 <= e.status_code < 500:
                raise
            if attempt < max_retries - 1:
                wait = 2 ** (attempt + 1)
                print(f"  API error ({e.status_code}), retrying in {wait}s...")
                time.sleep(wait)
            else:
                raise
        except anthropic.APIConnectionError:
            if attempt < max_retries - 1:
                wait = 2 ** (attempt + 1)
                print(f"  Connection error, retrying in {wait}s...")
                time.sleep(wait)
            else:
                raise
        except anthropic.APITimeoutError:
            if attempt < max_retries - 1:
                wait = 2 ** (attempt + 1)
                print(f"  API timeout ({api_timeout}s), retrying in {wait}s...")
                time.sleep(wait)
            else:
                raise
