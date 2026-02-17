"""GODMACHINE orchestrator — the perpetual loop that builds the world."""

import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

from codebase_summarizer import (
    classify_file_domain,
    compress_world_state,
    summarize_codebase,
    summarize_file_contents_tiered,
)
from cycle_logger import append_cycle, read_cycles
from godot_runner import (
    TestResult,
    pre_validate_gdscript,
    run_smoke_test,
    test_headless,
    validate_scene_refs,
)
from llm import build_cycle_prompt, call_llm, estimate_tokens, verify_intent
from strategy import GameCapabilities, determine_strategy, scan_capabilities
from twitter_poster import is_configured as twitter_configured, post_tweet

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

    # Extract learning
    m = re.search(r"<learning>(.*?)</learning>", response, re.DOTALL)
    result["learning"] = m.group(1).strip() if m else ""

    # Extract curated learnings (only present on curation cycles)
    m = re.search(r"<curated_learnings>(.*?)</curated_learnings>", response, re.DOTALL)
    result["curated_learnings"] = m.group(1).strip() if m else ""

    return result


def apply_files(parsed: dict, game_path: Path) -> list[str]:
    """Write files to disk. Returns list of paths written."""
    written = []
    game_path_resolved = game_path.resolve()
    for f in parsed["files"]:
        target = (game_path / f["path"].removeprefix("game/")).resolve()
        if not str(target).startswith(str(game_path_resolved)):
            print(f"  REJECTED path traversal: {f['path']}")
            continue
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
        stderr = e.stderr.decode("utf-8", errors="replace") if isinstance(e.stderr, bytes) else e.stderr
        print(f"  Git commit failed: {stderr}")
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
        stderr = e.stderr.decode("utf-8", errors="replace") if isinstance(e.stderr, bytes) else e.stderr
        print(f"  Rollback failed: {stderr}")
        return False


def update_world_state(world_state_path: Path, lore_entry: str, cycle_num: int) -> None:
    """Append a lore entry to world_state.xml."""
    if not lore_entry:
        return
    if not world_state_path.exists():
        print(f"  WARNING: {world_state_path} not found — lore entry dropped.")
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


# ---------------------------------------------------------------------------
# Learnings system
# ---------------------------------------------------------------------------

LEARNINGS_PATH = ROOT / "lore" / "learnings.md"
MAX_LEARNINGS = 50  # Keep the file from growing unbounded


def read_learnings() -> str:
    """Read the learnings file and return its contents."""
    if LEARNINGS_PATH.exists():
        return LEARNINGS_PATH.read_text(encoding="utf-8")
    return ""


def append_learning(learning: str, cycle_num: int, action: str, result: str) -> None:
    """Append a learning entry to learnings.md."""
    if not learning:
        return

    LEARNINGS_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Read existing
    existing = LEARNINGS_PATH.read_text(encoding="utf-8") if LEARNINGS_PATH.exists() else "# GODMACHINE Learnings\n\n"

    # Count existing entries
    entry_count = existing.count("\n- **Cycle")

    # Append new entry
    tag = "discovery" if result == "success" else "correction"
    entry = f"- **Cycle {cycle_num}** [{tag}] ({action}): {learning}\n"
    existing += entry

    # Trim if too many (keep header + last MAX_LEARNINGS entries)
    entries = [l for l in existing.splitlines(True) if l.startswith("- **Cycle")]
    if len(entries) > MAX_LEARNINGS:
        header = "# GODMACHINE Learnings\n\n"
        trimmed_entries = entries[-MAX_LEARNINGS:]
        existing = header + "".join(trimmed_entries)

    LEARNINGS_PATH.write_text(existing, encoding="utf-8")


def replace_learnings(curated_content: str) -> None:
    """Replace the entire learnings file with curated content."""
    if not curated_content:
        return
    LEARNINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    # Ensure header is present
    if not curated_content.startswith("# GODMACHINE Learnings"):
        curated_content = "# GODMACHINE Learnings\n\n" + curated_content
    LEARNINGS_PATH.write_text(curated_content, encoding="utf-8")
    print("  Learnings file replaced with curated version.")


# ---------------------------------------------------------------------------
# Phase 1D: Focus domain inference
# ---------------------------------------------------------------------------

def _infer_focus_domains(cycles: list[dict], strategy: str) -> list[str]:
    """Guess relevant domains from the last cycle's target."""
    if not cycles:
        return ["core"]

    last = cycles[-1]
    target = last.get("target", "")
    action = last.get("action", "")

    # On explore, we don't know what's next — give core context
    if strategy == "explore":
        return ["core"]

    # On retry/pivot, focus on the domain of the last target
    domain = classify_file_domain(target)
    domains = [domain] if domain != "other" else []

    # Always include core for context
    if "core" not in domains:
        domains.append("core")

    return domains


# ---------------------------------------------------------------------------
# Phase 3: Complexity budget
# ---------------------------------------------------------------------------

def check_complexity_budget(parsed: dict, config: dict) -> tuple[bool, str]:
    """Check if the LLM response is within complexity limits."""
    complexity_cfg = config.get("complexity", {})
    max_files = complexity_cfg.get("max_files_touched", 3)
    max_lines = complexity_cfg.get("max_total_lines", 400)
    max_new_ratio = complexity_cfg.get("max_new_file_ratio", 0.75)

    files = parsed.get("files", [])

    # Check file count
    if len(files) > max_files:
        return False, f"Too many files ({len(files)} > {max_files}). Keep changes smaller."

    # Check total lines
    total_lines = sum(f["content"].count("\n") + 1 for f in files)
    if total_lines > max_lines:
        return False, f"Too many lines ({total_lines} > {max_lines}). Simplify the change."

    # Check new file ratio
    if files:
        new_files = sum(1 for f in files if f["mode"] == "create")
        ratio = new_files / len(files)
        if ratio > max_new_ratio and len(files) > 1:
            return False, (
                f"Too many new files ({new_files}/{len(files)} = {ratio:.0%} > {max_new_ratio:.0%}). "
                "Prefer editing existing files or create fewer new ones."
            )

    return True, ""


# ---------------------------------------------------------------------------
# Phase 3: Post-mortem diff capture
# ---------------------------------------------------------------------------

def get_last_failed_diff() -> str:
    """Capture git diff of game/ before rollback, for next cycle's retry prompt."""
    try:
        result = subprocess.run(
            ["git", "diff", "HEAD", "--", "game/"],
            cwd=ROOT, capture_output=True, text=True, timeout=10,
        )
        diff = result.stdout.strip()
        # Limit diff size to avoid bloating prompt
        if len(diff) > 3000:
            diff = diff[:3000] + "\n... (diff truncated)"
        return diff
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Main cycle
# ---------------------------------------------------------------------------

def run_cycle(config: dict) -> None:
    """Execute one GODMACHINE cycle."""
    game_path = ROOT / config["paths"].get("game", "game")
    godot_exe = config["godot"]["executable"]
    cycle_log_path = ROOT / config["paths"]["cycle_log"]
    archive_path = ROOT / config["paths"]["cycle_archive"]
    world_state_path = ROOT / config["paths"]["world_state"]
    validation_cfg = config.get("validation", {})
    token_budget = config.get("context", {}).get("token_budget", 80000)

    # 1. Read state
    cycles = read_cycles(cycle_log_path)
    cycle_num = get_cycle_num(cycles)

    # Scan capabilities (Phase 2)
    capabilities = scan_capabilities(game_path)
    strategy, explanation = determine_strategy(cycles, capabilities)

    print(f"\n{'='*60}")
    print(f"CYCLE {cycle_num} — Strategy: {strategy.upper()}")
    print(f"  {explanation}")
    print(f"  Capabilities: {capabilities.summary()}")
    print(f"{'='*60}")

    # 2. Build context (tiered)
    cycle_log_xml = read_xml_text(cycle_log_path)
    world_state_xml = read_xml_text(world_state_path)
    world_state_xml = compress_world_state(world_state_xml)
    codebase_summary = summarize_codebase(game_path)

    focus_domains = _infer_focus_domains(cycles, strategy)
    file_contents = summarize_file_contents_tiered(
        game_path, focus_domains=focus_domains,
    )

    last_error = ""
    last_diff = ""
    if cycles and cycles[-1].get("result") == "fail":
        last_error = cycles[-1].get("error", "")
    # Load saved diff for retry (if it exists)
    diff_file = ROOT / "lore" / ".last_failed_diff"
    if last_error and config.get("prompt", {}).get("post_mortem_diff", False):
        if diff_file.exists():
            last_diff = diff_file.read_text(encoding="utf-8")

    learnings = read_learnings()

    # Curated learnings check
    learnings_cfg = config.get("learnings", {})
    curate_every = learnings_cfg.get("curate_every", 10)
    learnings_token_budget = learnings_cfg.get("max_token_budget", 4000)
    should_curate = curate_every > 0 and cycle_num % curate_every == 0 and learnings

    prompt = build_cycle_prompt(
        strategy=strategy,
        strategy_explanation=explanation,
        cycle_log_xml=cycle_log_xml,
        world_state_xml=world_state_xml,
        codebase_summary=codebase_summary,
        file_contents=file_contents,
        cycle_num=cycle_num,
        last_error=last_error,
        capabilities_summary=capabilities.summary(),
        last_diff=last_diff,
        learnings=learnings,
        token_budget=token_budget,
        curate_learnings=should_curate,
        learnings_token_budget=learnings_token_budget,
    )

    if should_curate:
        print("  Curation cycle — learnings compression requested.")

    print(f"  Prompt tokens: ~{estimate_tokens(prompt)}")

    # 3. Call LLM
    print("  Calling Claude...")
    try:
        response = call_llm(prompt, config=config)
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
    if parsed.get("learning"):
        print(f"  Learning: {parsed['learning'][:80]}...")

    if not parsed["files"]:
        print("  No files in response — skipping.")
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="fail", error="LLM returned no files",
        )
        return

    # 4.5 Complexity budget check (Phase 3)
    within_budget, budget_reason = check_complexity_budget(parsed, config)
    if not within_budget:
        print(f"  Complexity budget exceeded: {budget_reason}")
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="fail", error=f"Complexity budget: {budget_reason}",
        )
        return

    # 5. Apply changes
    print("  Applying changes...")
    written = apply_files(parsed, game_path)

    # 5.5 Pre-validation (Phase 1)
    if validation_cfg.get("pre_validate", False):
        print("  Pre-validating...")
        pre_errors = []
        for filepath in written:
            if filepath.endswith(".gd"):
                pre_errors.extend(pre_validate_gdscript(Path(filepath)))

        if validation_cfg.get("scene_ref_check", False):
            pre_errors.extend(validate_scene_refs(game_path, written))

        if pre_errors:
            error_msg = "\n".join(str(e) for e in pre_errors[:validation_cfg.get("max_errors_in_prompt", 5)])
            print(f"  Pre-validation FAILED:\n{error_msg}")

            # Save diff before rollback
            diff = get_last_failed_diff()
            if diff:
                diff_file.parent.mkdir(parents=True, exist_ok=True)
                diff_file.write_text(diff, encoding="utf-8")

            git_rollback()
            append_learning(parsed.get("learning", ""), cycle_num, parsed["action"], "fail")
            append_cycle(
                cycle_log_path, archive_path,
                cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
                result="fail", error=error_msg,
            )
            return

    # 6. Test headless
    quit_after = validation_cfg.get("extended_quit_after", 2) if validation_cfg.get("smoke_test", False) else 2
    print("  Testing headless...")
    test_result = test_headless(godot_exe, game_path, quit_after=quit_after)
    print(f"  Test result: {'PASS' if test_result.success else 'FAIL'}")

    if not test_result.success:
        error_summary = test_result.error_summary(
            max_errors=validation_cfg.get("max_errors_in_prompt", 5)
        )
        print(f"  Errors:\n{error_summary}")

        # Save diff before rollback
        diff = get_last_failed_diff()
        if diff:
            diff_file.parent.mkdir(parents=True, exist_ok=True)
            diff_file.write_text(diff, encoding="utf-8")

        git_rollback()
        append_learning(parsed.get("learning", ""), cycle_num, parsed["action"], "fail")
        append_cycle(
            cycle_log_path, archive_path,
            cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
            result="fail", error=error_summary,
        )
        return

    # 6.5 Optional smoke test (Phase 2)
    if validation_cfg.get("smoke_test", False):
        print("  Running smoke test...")
        smoke_result = run_smoke_test(godot_exe, game_path)
        if not smoke_result.success:
            smoke_error = smoke_result.error_summary()
            print(f"  Smoke test FAILED:\n{smoke_error}")

            diff = get_last_failed_diff()
            if diff:
                diff_file.parent.mkdir(parents=True, exist_ok=True)
                diff_file.write_text(diff, encoding="utf-8")

            git_rollback()
            append_learning(parsed.get("learning", ""), cycle_num, parsed["action"], "fail")
            append_cycle(
                cycle_log_path, archive_path,
                cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
                result="fail", error=f"Smoke test: {smoke_error}",
            )
            return

    # 6.7 Intent verification (cheap Haiku call)
    if validation_cfg.get("intent_check", False):
        print("  Verifying intent...")
        # Build a dict of path -> content for the files written
        files_for_check = {
            f["path"]: f["content"] for f in parsed["files"]
        }
        intent_model = validation_cfg.get("intent_check_model", "claude-haiku-4-5-20251001")
        intent_passed, intent_reason = verify_intent(
            parsed["action"], parsed["target"], files_for_check, model=intent_model,
        )
        if not intent_passed:
            print(f"  Intent check FAILED: {intent_reason}")

            diff = get_last_failed_diff()
            if diff:
                diff_file.parent.mkdir(parents=True, exist_ok=True)
                diff_file.write_text(diff, encoding="utf-8")

            git_rollback()
            append_learning(parsed.get("learning", ""), cycle_num, parsed["action"], "fail")
            append_cycle(
                cycle_log_path, archive_path,
                cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
                result="fail", error=f"Intent check: {intent_reason}",
            )
            return
        print(f"  Intent check PASSED{': ' + intent_reason if intent_reason else ''}")

    # 7. Success — update lore/learnings first, then commit everything together
    # Clean up saved diff on success
    if diff_file.exists():
        diff_file.unlink()

    update_world_state(world_state_path, parsed.get("lore_entry", ""), cycle_num)
    append_learning(parsed.get("learning", ""), cycle_num, parsed["action"], "success")

    # Replace learnings with curated version if present (only on success)
    if parsed.get("curated_learnings"):
        replace_learnings(parsed["curated_learnings"])

    append_cycle(
        cycle_log_path, archive_path,
        cycle_num=cycle_num, action=parsed["action"], target=parsed["target"],
        result="success", note=parsed.get("patch_notes", ""),
    )

    if not git_commit(f"Cycle {cycle_num}: {parsed['action']} {parsed['target']}"):
        print("  Commit failed — rolling back.")
        git_rollback()
        return

    if parsed.get("patch_notes"):
        print(f"\n  GODMACHINE speaks:\n  \"{parsed['patch_notes']}\"")

        # Post to Twitter if configured
        if config.get("twitter", {}).get("enabled", False) and twitter_configured():
            post_tweet(parsed["patch_notes"])


def main():
    config = load_config()

    print("GODMACHINE ORCHESTRATOR")
    print(f"  Config: {CONFIG_PATH}")

    cycles_run = 0
    while True:
        # Reload config each cycle for hot-swapping settings
        config = load_config()
        interval = config.get("cycle", {}).get("interval_seconds", 300)
        max_cycles = config.get("cycle", {}).get("max_cycles", -1)

        print(f"\n  Model: {config.get('prompt', {}).get('model', 'default')}")
        print(f"  Token budget: {config.get('context', {}).get('token_budget', 80000)}")
        print(f"  Twitter: {'enabled' if config.get('twitter', {}).get('enabled', False) and twitter_configured() else 'disabled'}")

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
