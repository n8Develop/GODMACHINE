"""Read/write the cycle log XML. Keeps last ~20 entries in the active log."""

import xml.etree.ElementTree as ET
from pathlib import Path

MAX_ACTIVE_CYCLES = 20


def read_cycles(cycle_log_path: Path) -> list[dict]:
    """Parse cycle_log.xml into a list of dicts."""
    if not cycle_log_path.exists():
        return []
    tree = ET.parse(cycle_log_path)
    root = tree.getroot()
    cycles = []
    for el in root.findall("cycle"):
        cycles.append(dict(el.attrib))
    return cycles


def append_cycle(
    cycle_log_path: Path,
    archive_path: Path,
    *,
    cycle_num: int,
    action: str,
    target: str,
    result: str,
    error: str = "",
    note: str = "",
) -> None:
    """Append a cycle entry. Archive old entries beyond MAX_ACTIVE_CYCLES."""
    # Read or create log
    if cycle_log_path.exists():
        tree = ET.parse(cycle_log_path)
        root = tree.getroot()
    else:
        root = ET.Element("cycle_log")
        tree = ET.ElementTree(root)

    # Build new entry
    attrs = {"day": str(cycle_num), "action": action, "target": target, "result": result}
    if error:
        attrs["error"] = error
    if note:
        attrs["note"] = note
    ET.SubElement(root, "cycle", attrs)

    # Archive if too many
    all_cycles = root.findall("cycle")
    if len(all_cycles) > MAX_ACTIVE_CYCLES:
        overflow = all_cycles[: len(all_cycles) - MAX_ACTIVE_CYCLES]
        _archive_cycles(archive_path, overflow)
        for el in overflow:
            root.remove(el)

    _indent(root)
    tree.write(cycle_log_path, encoding="unicode", xml_declaration=True)


def _archive_cycles(archive_path: Path, elements: list[ET.Element]) -> None:
    """Move cycle elements to the archive file."""
    if archive_path.exists():
        tree = ET.parse(archive_path)
        root = tree.getroot()
    else:
        root = ET.Element("cycle_archive")
        tree = ET.ElementTree(root)

    for el in elements:
        root.append(el)

    _indent(root)
    tree.write(archive_path, encoding="unicode", xml_declaration=True)


def _indent(elem: ET.Element, level: int = 0) -> None:
    """Add indentation to XML elements for readability."""
    indent = "\n" + "  " * level
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = indent + "  "
        if not elem.tail or not elem.tail.strip():
            elem.tail = indent
        for child in elem:
            _indent(child, level + 1)
        if not child.tail or not child.tail.strip():
            child.tail = indent
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = indent
