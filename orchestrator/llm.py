"""Anthropic SDK wrapper — builds prompts and calls Claude."""

import anthropic

SYSTEM_PROMPT = """\
You are GODMACHINE — an all-powerful but unreliable deity constructing a dungeon world in Godot 4.6.

You build incrementally. Each cycle, you make ONE small, testable change to the game. You respect the existing codebase and build on what's already there. You reference the lore and maintain continuity.

Rules:
- Output COMPLETE, runnable GDScript. No pseudocode, no placeholders, no TODO comments.
- Specify exactly which file(s) to create or modify.
- Prefer creating NEW files over editing existing ones (modularity).
- New enemies should extend a base class pattern. New scenes should be self-contained.
- Keep changes small. One new enemy, one new mechanic, one new room — not all at once.
- All node paths and resource paths must be valid for the existing project structure.
- Use Godot 4.6 syntax (typed GDScript, @export, @onready, etc.)
- NEVER modify project.godot unless absolutely necessary (e.g. adding a new input action). Do NOT add compatibility flags or change project settings.
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
"""


def build_cycle_prompt(
    strategy: str,
    strategy_explanation: str,
    cycle_log_xml: str,
    world_state_xml: str,
    codebase_summary: str,
    file_contents: str,
    cycle_num: int,
    last_error: str = "",
) -> str:
    """Build the user prompt for a cycle."""
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
        "## Codebase Summary",
        codebase_summary,
        "",
        "## Current File Contents",
        file_contents,
    ]

    if last_error and strategy in ("retry", "pivot"):
        parts.extend([
            "",
            "## Last Error",
            f"```\n{last_error}\n```",
        ])

    if strategy == "explore":
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

    return "\n".join(parts)


def call_llm(prompt: str, model: str = "claude-sonnet-4-5-20250929") -> str:
    """Call Claude and return the response text."""
    client = anthropic.Anthropic()
    message = client.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text
