"""GODMACHINE orchestrator — the perpetual loop that builds the world."""

import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

from codebase_summarizer import summarize_codebase, summarize_file_contents
from cycle_logger import append_cycle, read_cycles
from godot_runner import test_headless
from llm import build_cycle_prompt, call_llm
from strategy import determine_strategy

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = Path(__file__).resolve().parent / "config.yaml"


def load_config() -> dict:
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_cycle_num(cycles: list[dict]) -> int:
    if not cycles:
        return 1
    return max(int(c.get("day", 0)) for c in cycles) + 1


def read_xml_text(path: Path) -> str:
    if path.exists():
        return path.read_text(encoding="utf-8")
    return ""


def parse_response(response: str) -> dict:
    """Parse the LLM response into structured parts."""
    result = {}

    # Extract action
    m = re.search(r"<action>(.*?)</action>", response, re.DOTALL)
    result["action"] = m.group(1).strip() if m else "unknown"

    # Extract target
    m = re.search(r"<target>(.*?)</target>", response, re.DOTALL)
    result["target"] = m.group(1).strip() if m else "unknown"

    # Extract files
    result["files"] = []
    for m in re.finditer(
        r'<file\s+path="([^"]+)"\s+mode="([^"]+)">(.*?)</file>',
        response,
        re.DOTALL,
    ):
        result["files"].append({
            "path": m.group(1).strip(),
            "mode": m.group(2).strip(),
            "content": m.group(3).strip("\n"),
        })

    # Extract lore entry
    m = re.search(r"<lore_entry>(.*?)</lore_entry>", response, re.DOTALL)
    result["lore_entry"] = m.group(1).strip() if m else ""

    # Extract patch notes
    m = re.search(r"<patch_notes>(.*?)</patch_notes>", response, re.DOTALL)
    result["patch_notes"] = m.group(1).strip() if m else ""

    return result


def apply_files(parsed: dict, game_path: Path) -> list[str]:
    """Write files to disk. Returns list of paths written."""
    written = []
    for f in parsed["files"]:
        target = game_path / f["path"].removeprefix("game/")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(f["content"], encoding="utf-8")
        written.append(str(target))
        print(f"  Wrote: {target}")
    return written


def git_commit(message: str) -> bool:
    """Stage all changes in game/ and commit."""
    try:
        subprocess.run(["git", "add", "game/", "lore/"], cwd=ROOT, check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", message],
            cwd=ROOT, check=True, capture_output=True,
        )
        print(f"  Committed: {message}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  Git commit failed: {e.stderr}")
        return False


def git_rollback() -> bool:
    """Revert uncommitted changes in game/."""
    try:
        subprocess.run(
            ["git", "checkout", "--", "game/"],
            cwd=ROOT, check=True, capture_output=True,
        )
        # Also clean untracked files in game/
        subprocess.run(
            ["git", "clean", "-fd", "game/"],
            cwd=ROOT, check=True, capture_output=True,
        )
        print("  Rolled back changes.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  Rollback failed: {e.stderr}")
        return False


def update_world_state(world_state_path: Path, lore_entry: str, cycle_num: int) -> None:
    """Append a lore entry to world_state.xml."""
    if not lore_entry or not world_state_path.exists():
        return

    tree = ET.parse(world_state_path)
    root = tree.getroot()

    # Update current_day
    root.set("current_day", str(cycle_num))

    # Find or create chronicle
    chronicle = root.find("chronicle")
    if chronicle is None:
        chronicle = ET.SubElement(root, "chronicle")

    entry = ET.SubElement(chronicle, "entry", day=str(cycle_num))
    entry.text = lore_entry

    tree.write(world_state_path, encoding="unicode", xml_declaration=True)


def run_cycle(config: dict) -> None:
    """Execute one GODMACHINE cycle."""
    game_path = ROOT / config["paths"].get("game", "game")
    godot_exe = config["godot"]["executable"]
    cycle_log_path = ROOT / config["paths"]["cycle_log"]
    archive_path = ROOT / config["paths"]["cycle_archive"]
    world_state_path = ROOT / config["paths"]["world_state"]

    # 1. Read state
    cycles = read_cycles(cycle_log_path)
    cycle_num = get_cycle_num(cycles)
    strategy, explanation = determine_strategy(cycles)

    print(f"\n{'='*60}")
    print(f"CYCLE {cycle_num} — Strategy: {strategy.upper()}")
    print(f"  {explanation}")
    print(f"{'='*60}")

    # 2. Build context
    cycle_log_xml = read_xml_text(cycle_log_path)
    world_state_xml = read_xml_text(world_state_path)
    codebase_summary = summarize_codebase(game_path)
    file_contents = summarize_file_contents(game_path)

    last_error = ""
    if cycles and cycles[-1].get("result") == "fail":
        last_error = cycles[-1].get("error", "")

    prompt = build_cycle_prompt(
        strategy=strategy,
        strategy_explanation=explanation,
        cycle_log_xml=cycle_log_xml,
        world_state_xml=world_state_xml,
        codebase_summary=codebase_summary,
        file_contents=file_contents,
        cycle_num=cycle_num,
        last_error=last_error,
    )

    # 3. Call LLM
    print("  Calling Claude...")
    try:
        response = call_llm(prompt)
    except Exception as e:
        print(f"  LLM call failed: {e}")
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action="llm_call", target="api",
            result="fail", error=str(e),
        )
        return

    # 4. Parse response
    parsed = parse_response(response)
    print(f"  Action: {parsed['action']} -> {parsed['target']}")
    print(f"  Files: {len(parsed['files'])}")

    if not parsed["files"]:
        print("  No files in response — skipping.")
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="fail", error="LLM returned no files",
        )
        return

    # 5. Apply changes
    print("  Applying changes...")
    apply_files(parsed, game_path)

    # 6. Test
    print("  Testing headless...")
    success, output = test_headless(godot_exe, game_path)
    print(f"  Test result: {'PASS' if success else 'FAIL'}")
    if not success:
        print(f"  Output: {output[:500]}")

    # 7. Commit or rollback
    if success:
        git_commit(f"Cycle {cycle_num}: {parsed['action']} {parsed['target']}")
        update_world_state(world_state_path, parsed.get("lore_entry", ""), cycle_num)
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="success", note=parsed.get("patch_notes", ""),
        )
        if parsed.get("patch_notes"):
            print(f"\n  GODMACHINE speaks:\n  \"{parsed['patch_notes']}\"")
    else:
        git_rollback()
        # Truncate error for the log
        error_short = output[:200] if output else "unknown error"
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="fail", error=error_short,
        )


def main():
    config = load_config()
    interval = config.get("cycle", {}).get("interval_seconds", 300)
    max_cycles = config.get("cycle", {}).get("max_cycles", -1)

    print("GODMACHINE ORCHESTRATOR")
    print(f"  Cycle interval: {interval}s")
    print(f"  Max cycles: {'unlimited' if max_cycles == -1 else max_cycles}")

    cycles_run = 0
    while True:
        try:
            run_cycle(config)
        except Exception as e:
            print(f"\n  CYCLE CRASHED: {e}")
            import traceback
            traceback.print_exc()

        cycles_run += 1
        if max_cycles != -1 and cycles_run >= max_cycles:
            print(f"\nReached max cycles ({max_cycles}). Stopping.")
            break

        print(f"\n  Sleeping {interval}s until next cycle...")
        time.sleep(interval)


if __name__ == "__main__":
    main()
