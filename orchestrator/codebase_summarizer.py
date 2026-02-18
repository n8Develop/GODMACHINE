"""Scan the game/ directory and produce a concise summary for the LLM."""

import re
import xml.etree.ElementTree as ET
from pathlib import Path

# ---------------------------------------------------------------------------
# Domain classification
# ---------------------------------------------------------------------------

DOMAIN_KEYWORDS: dict[str, list[str]] = {
    "enemies": ["enemy", "watcher", "boss", "mob", "minion", "spawner"],
    "items": ["pickup", "item", "loot", "potion", "key", "treasure", "shrine"],
    "rooms": ["room", "door", "level", "corridor", "chamber", "dungeon"],
    "core": ["player", "game_manager", "projectile", "camera", "main"],
    "ui": ["hud", "menu", "ui", "health_bar", "label", "button", "dialog"],
}


def classify_file_domain(filepath: str) -> str:
    """Categorize a game file into a domain based on its filename."""
    name = Path(filepath).stem.lower()
    for domain, keywords in DOMAIN_KEYWORDS.items():
        if any(kw in name for kw in keywords):
            return domain
    return "other"


def _extract_signatures(path: Path) -> str:
    """Pull extends, class_name, @export, func, signal, const lines from a .gd file."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return "(unreadable)"

    sig_patterns = re.compile(
        r"^\s*("
        r"extends\s|class_name\s|@export\s|func\s|signal\s|const\s"
        r")"
    )

    sigs = []
    for line in lines:
        if sig_patterns.match(line):
            sigs.append(line.rstrip())
    return "\n".join(sigs) if sigs else "(no signatures)"


# ---------------------------------------------------------------------------
# Tiered summarization
# ---------------------------------------------------------------------------

def summarize_file_contents_tiered(
    game_path: Path,
    focus_domains: list[str] | None = None,
    edit_targets: list[str] | None = None,
) -> str:
    """Return file contents with three tiers of detail.

    - FULL SOURCE: files in focus_domains or edit_targets
    - FUNCTION SIGNATURES: files in related domains
    - FILENAME ONLY: everything else
    """
    focus_domains = focus_domains or []
    edit_targets = [t.lower() for t in (edit_targets or [])]

    full_parts: list[str] = []
    sig_parts: list[str] = []
    name_parts: list[str] = []

    # Collect .gd scripts
    scripts_dir = game_path / "scripts"
    if scripts_dir.exists():
        for script in sorted(scripts_dir.rglob("*.gd")):
            rel = str(script.relative_to(game_path))
            domain = classify_file_domain(rel)

            # Check if this is an edit target (by filename match)
            is_edit_target = any(t in rel.lower() for t in edit_targets) if edit_targets else False

            if is_edit_target or domain in focus_domains:
                content = script.read_text(encoding="utf-8")
                full_parts.append(f"### {rel} (FULL)\n```gdscript\n{content}\n```")
            elif _is_related_domain(domain, focus_domains):
                sigs = _extract_signatures(script)
                sig_parts.append(f"### {rel} (signatures)\n```\n{sigs}\n```")
            else:
                # Include extends line so the LLM knows what each script is
                summary = _extract_script_summary(script)
                name_parts.append(f"- {rel} — {summary}")

    # Collect .tscn scenes
    scenes_dir = game_path / "scenes"
    if scenes_dir.exists():
        for scene in sorted(scenes_dir.rglob("*.tscn")):
            rel = str(scene.relative_to(game_path))
            domain = classify_file_domain(rel)

            is_edit_target = any(t in rel.lower() for t in edit_targets) if edit_targets else False

            if is_edit_target or domain in focus_domains:
                content = scene.read_text(encoding="utf-8")
                full_parts.append(f"### {rel} (FULL)\n```\n{content}\n```")
            else:
                name_parts.append(f"- {rel}")

    # Include project.godot (autoloads, input actions, physics layers)
    project_file = game_path / "project.godot"
    if project_file.exists():
        try:
            content = project_file.read_text(encoding="utf-8")
            full_parts.insert(0, f"### project.godot (FULL)\n```ini\n{content}\n```")
        except Exception:
            pass

    sections = []
    if full_parts:
        sections.append("#### Full Source\n" + "\n\n".join(full_parts))
    if sig_parts:
        sections.append("#### Signatures Only\n" + "\n\n".join(sig_parts))
    if name_parts:
        sections.append("#### Other Files\n" + "\n".join(name_parts))

    return "\n\n".join(sections) if sections else ""


def _is_related_domain(domain: str, focus_domains: list[str]) -> bool:
    """Check if a domain is closely related to any focus domain."""
    RELATED: dict[str, list[str]] = {
        "enemies": ["core", "rooms"],
        "items": ["core", "rooms"],
        "rooms": ["core", "enemies", "items"],
        "core": ["enemies", "items", "rooms", "ui"],
        "ui": ["core"],
    }
    for fd in focus_domains:
        if domain in RELATED.get(fd, []):
            return True
    return False


# ---------------------------------------------------------------------------
# World state compression
# ---------------------------------------------------------------------------

def compress_world_state(xml_text: str, max_entries: int = 10) -> str:
    """Keep last N chronicle entries verbatim, summarize older ones in batches of 3."""
    if not xml_text.strip():
        return xml_text

    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return xml_text

    chronicle = root.find("chronicle")
    if chronicle is None:
        return xml_text

    entries = chronicle.findall("entry")
    if len(entries) <= max_entries:
        return xml_text

    # Split into old (to summarize) and recent (to keep verbatim)
    old_entries = entries[:-max_entries]
    recent_entries = entries[-max_entries:]

    # Remove all entries from chronicle
    for e in list(chronicle):
        chronicle.remove(e)

    # Summarize old entries in batches of 3
    for i in range(0, len(old_entries), 3):
        batch = old_entries[i : i + 3]
        days = [e.get("day", "?") for e in batch]
        day_range = f"{days[0]}-{days[-1]}"
        summary_text = "; ".join(
            (e.text or "").strip()[:120] + "..." if len((e.text or "").strip()) > 120 else (e.text or "").strip()
            for e in batch
        )
        summary_el = ET.SubElement(chronicle, "summary", days=day_range)
        summary_el.text = summary_text

    # Re-add recent entries verbatim
    for e in recent_entries:
        chronicle.append(e)

    return ET.tostring(root, encoding="unicode", xml_declaration=True)


# ---------------------------------------------------------------------------
# Original functions (backward compat)
# ---------------------------------------------------------------------------

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
    """Return the full contents of all GDScript files — thin wrapper for backward compat."""
    return summarize_file_contents_tiered(game_path)


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
