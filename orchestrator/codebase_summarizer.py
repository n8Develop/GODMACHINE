"""Scan the game/ directory and produce a concise summary for the LLM."""

from pathlib import Path


def summarize_codebase(game_path: Path) -> str:
    """Return a markdown summary of all scripts and scenes in the project."""
    sections = []

    # Scripts
    scripts_dir = game_path / "scripts"
    if scripts_dir.exists():
        scripts = sorted(scripts_dir.rglob("*.gd"))
        if scripts:
            sections.append("## Scripts")
            for script in scripts:
                rel = script.relative_to(game_path)
                summary = _extract_script_summary(script)
                sections.append(f"- **{rel}**: {summary}")

    # Scenes
    scenes_dir = game_path / "scenes"
    if scenes_dir.exists():
        scenes = sorted(scenes_dir.rglob("*.tscn"))
        if scenes:
            sections.append("## Scenes")
            for scene in scenes:
                rel = scene.relative_to(game_path)
                sections.append(f"- **{rel}**")

    # Assets
    assets_dir = game_path / "assets"
    if assets_dir.exists():
        assets = sorted(assets_dir.rglob("*"))
        assets = [a for a in assets if a.is_file()]
        if assets:
            sections.append(f"## Assets ({len(assets)} files)")

    if not sections:
        return "Empty project — no scripts or scenes yet."

    return "\n".join(sections)


def summarize_file_contents(game_path: Path) -> str:
    """Return the full contents of all GDScript files, for LLM context."""
    parts = []
    scripts_dir = game_path / "scripts"
    if not scripts_dir.exists():
        return ""

    for script in sorted(scripts_dir.rglob("*.gd")):
        rel = script.relative_to(game_path)
        content = script.read_text(encoding="utf-8")
        parts.append(f"### {rel}\n```gdscript\n{content}\n```")

    return "\n\n".join(parts)


def _extract_script_summary(path: Path) -> str:
    """Pull the first doc comment or 'extends' line as a one-line summary."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return "(unreadable)"

    # Look for ## doc comment at top
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("##"):
            return stripped.lstrip("#").strip()
        if stripped.startswith("extends"):
            return stripped
        if stripped and not stripped.startswith("#"):
            break

    # Fallback: first extends line anywhere
    for line in lines:
        if line.strip().startswith("extends"):
            return line.strip()

    return "(no summary)"
