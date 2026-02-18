"""Adaptive strategy selection: explore / retry / pivot, with capability tracking."""

import re
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Game capability tracking (Phase 2)
# ---------------------------------------------------------------------------

@dataclass
class GameCapabilities:
    enemies: list[str] = field(default_factory=list)
    items: list[str] = field(default_factory=list)
    rooms: list[str] = field(default_factory=list)
    mechanics: list[str] = field(default_factory=list)
    ui_elements: list[str] = field(default_factory=list)
    autoloads: list[str] = field(default_factory=list)

    def summary(self) -> str:
        """Markdown summary for prompt injection."""
        lines = []
        if self.enemies:
            lines.append(f"- **Enemies**: {', '.join(self.enemies)}")
        if self.items:
            lines.append(f"- **Items**: {', '.join(self.items)}")
        if self.rooms:
            lines.append(f"- **Rooms**: {', '.join(self.rooms)}")
        if self.mechanics:
            lines.append(f"- **Mechanics**: {', '.join(self.mechanics)}")
        if self.ui_elements:
            lines.append(f"- **UI**: {', '.join(self.ui_elements)}")
        if self.autoloads:
            lines.append(f"- **Autoloads**: {', '.join(self.autoloads)}")
        return "\n".join(lines) if lines else "(empty game — nothing built yet)"


def scan_capabilities(game_path: Path) -> GameCapabilities:
    """Scan the game directory to discover what exists."""
    caps = GameCapabilities()

    scripts_dir = game_path / "scripts"
    scenes_dir = game_path / "scenes"

    # Scan scripts by filename/extends patterns
    if scripts_dir.exists():
        for script in scripts_dir.rglob("*.gd"):
            name = script.stem.lower()
            try:
                content = script.read_text(encoding="utf-8")
            except Exception:
                continue

            extends_line = ""
            for line in content.splitlines():
                stripped = line.strip()
                if stripped.startswith("extends"):
                    extends_line = stripped.lower()
                    break

            if "enemy" in name or "enemy_base" in extends_line:
                if name != "enemy_base":  # Don't count the base class
                    caps.enemies.append(script.stem)
            elif any(kw in name for kw in ("pickup", "item", "loot", "potion", "shrine", "key")):
                caps.items.append(script.stem)
            elif "room" in name or "door" in name:
                caps.rooms.append(script.stem)
            elif any(kw in name for kw in ("hud", "menu", "ui", "health_bar", "dialog")):
                caps.ui_elements.append(script.stem)
            elif name not in ("player", "game_manager", "main"):
                # Anything else that isn't core is a mechanic
                if "projectile" in name or "camera" in name:
                    caps.mechanics.append(script.stem)

    # Scan scenes for rooms
    if scenes_dir.exists():
        for scene in scenes_dir.rglob("*.tscn"):
            name = scene.stem.lower()
            if "room" in name and scene.stem not in [r.lower() for r in caps.rooms]:
                caps.rooms.append(scene.stem)

    # Scan project.godot for autoloads
    project_file = game_path / "project.godot"
    if project_file.exists():
        try:
            content = project_file.read_text(encoding="utf-8")
            for m in re.finditer(r'autoload/(\w+)\s*=', content):
                caps.autoloads.append(m.group(1))
        except Exception:
            pass

    return caps


# ---------------------------------------------------------------------------
# Feature dependencies
# ---------------------------------------------------------------------------

FEATURE_DEPENDENCIES: dict[str, list[str]] = {
    "boss": ["enemies"],
    "shop": ["items"],
    "inventory": ["items"],
    "quest": ["rooms", "items"],
    "npc_dialog": ["rooms"],
    "minimap": ["rooms"],
    "equipment": ["items"],
    "crafting": ["items"],
}


def check_dependencies(feature: str, capabilities: GameCapabilities) -> list[str]:
    """Return missing prerequisites for a feature."""
    deps = FEATURE_DEPENDENCIES.get(feature.lower(), [])
    missing = []
    for dep in deps:
        cap_list = getattr(capabilities, dep, [])
        if not cap_list:
            missing.append(dep)
    return missing


# ---------------------------------------------------------------------------
# Domain cooldown
# ---------------------------------------------------------------------------

def get_recent_domains(cycles: list[dict], lookback: int = 5) -> list[str]:
    """Extract domains from recent cycle targets."""
    from codebase_summarizer import classify_file_domain

    domains = []
    for cycle in cycles[-lookback:]:
        target = cycle.get("target", "")
        if target:
            domain = classify_file_domain(target)
            domains.append(domain)
    return domains


def suggest_underrepresented_domain(
    capabilities: GameCapabilities,
    recent_domains: list[str],
) -> str | None:
    """Suggest a domain that hasn't been worked on recently."""
    all_domains = {
        "enemies": len(capabilities.enemies),
        "items": len(capabilities.items),
        "rooms": len(capabilities.rooms),
        "ui": len(capabilities.ui_elements),
    }

    # Find domains not recently touched
    untouched = [d for d in all_domains if d not in recent_domains]
    if not untouched:
        return None

    # Prefer the one with the fewest entries
    untouched.sort(key=lambda d: all_domains[d])
    return untouched[0]


# ---------------------------------------------------------------------------
# Error pattern analysis
# ---------------------------------------------------------------------------

def _analyze_error_patterns(cycles: list[dict], lookback: int = 5) -> dict[str, int]:
    """Count error categories in recent failed cycles."""
    patterns: dict[str, int] = {}
    for cycle in cycles[-lookback:]:
        if cycle.get("result") != "fail":
            continue
        error = cycle.get("error", "")
        if "Complexity budget" in error:
            patterns["complexity_budget"] = patterns.get("complexity_budget", 0) + 1
        elif "Intent check" in error:
            patterns["intent_check"] = patterns.get("intent_check", 0) + 1
        elif "Pre-validation" in error or "preload" in error.lower():
            patterns["pre_validation"] = patterns.get("pre_validation", 0) + 1
        elif "LLM returned no files" in error:
            patterns["no_output"] = patterns.get("no_output", 0) + 1
    return patterns


_ERROR_PATTERN_ADVICE: dict[str, str] = {
    "complexity_budget": (
        "PATTERN: Recent failures are hitting the complexity budget. "
        "Keep it to 2 files max, under 300 lines total. "
        "Edit existing files rather than creating new ones."
    ),
    "intent_check": (
        "PATTERN: Recent code didn't match the stated intent. "
        "Be precise about what you're building and make sure the code actually does it."
    ),
    "pre_validation": (
        "PATTERN: Recent failures have bad resource paths or syntax errors. "
        "Double-check all res:// paths and bracket matching."
    ),
    "no_output": (
        "PATTERN: Recent attempts produced no files. "
        "Make sure to include concrete file changes, not just descriptions."
    ),
}


# ---------------------------------------------------------------------------
# Strategy determination
# ---------------------------------------------------------------------------

def determine_strategy(
    cycles: list[dict],
    capabilities: GameCapabilities | None = None,
    soul_intentions: str = "",
) -> tuple[str, str]:
    """Return (strategy, explanation) based on recent cycle history."""
    if not cycles:
        return "explore", "No history yet — start building."

    recent = cycles[-3:]
    last = recent[-1]

    # Analyze error patterns across recent cycles (not just same-target)
    error_patterns = _analyze_error_patterns(cycles)
    pattern_advice = ""
    for pattern, count in error_patterns.items():
        if count >= 2 and pattern in _ERROR_PATTERN_ADVICE:
            pattern_advice = _ERROR_PATTERN_ADVICE[pattern]
            break  # Most frequent pattern wins

    if last["result"] == "success":
        explanation = "Last cycle succeeded. Try something new and ambitious."

        # Add domain nudges if capabilities provided
        if capabilities:
            recent_domains = get_recent_domains(cycles)
            suggestion = suggest_underrepresented_domain(capabilities, recent_domains)
            if suggestion:
                explanation += f" Consider adding something in the '{suggestion}' domain — it's underrepresented."

        # Even after success, warn if there's a recurring error pattern
        if pattern_advice:
            explanation += f" {pattern_advice}"

        # Soul influence — subtle, not a hard constraint
        if soul_intentions:
            explanation += f" Your soul whispers: {soul_intentions[:200]}"

        return "explore", explanation

    # Count consecutive failures on the same target
    current_target = last.get("target", "")
    consecutive_fails = 0
    for cycle in reversed(recent):
        if cycle.get("target") == current_target and cycle["result"] == "fail":
            consecutive_fails += 1
        else:
            break

    # Also count total recent failures (any target)
    recent_fail_count = sum(1 for c in cycles[-5:] if c.get("result") == "fail")

    if consecutive_fails >= 3:
        explanation = (
            f"Failed at '{current_target}' {consecutive_fails} times. "
            "Abandon it and try something completely different."
        )
        if pattern_advice:
            explanation += f" {pattern_advice}"
        return "pivot", explanation

    # Pivot if too many recent failures even on different targets
    if recent_fail_count >= 4:
        explanation = (
            f"Too many recent failures ({recent_fail_count}/5). "
            "Pick something simple and small that's likely to succeed."
        )
        if pattern_advice:
            explanation += f" {pattern_advice}"
        return "pivot", explanation

    explanation = (
        f"Last attempt at '{current_target}' failed: {last.get('error', 'unknown')}. "
        "Try a different approach to the same thing."
    )

    if pattern_advice:
        explanation += f" {pattern_advice}"

    # Add dependency warnings if capabilities provided
    if capabilities:
        missing = check_dependencies(current_target, capabilities)
        if missing:
            explanation += f" WARNING: '{current_target}' may need [{', '.join(missing)}] first."

    return "retry", explanation
