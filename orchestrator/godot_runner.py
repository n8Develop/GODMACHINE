"""Run Godot headless to test the project, with structured error parsing."""

import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class GodotError:
    category: str  # parse_error, missing_node, null_access, scene_error, method_error, missing_resource, validation
    file: str
    line: int
    message: str
    suggestion: str = ""

    def __str__(self) -> str:
        parts = [f"[{self.category}] {self.file}:{self.line} — {self.message}"]
        if self.suggestion:
            parts.append(f"  Fix: {self.suggestion}")
        return "\n".join(parts)


@dataclass
class TestResult:
    success: bool
    raw_output: str
    errors: list[GodotError] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def __iter__(self):
        """Backward-compat: allow `success, output = test_headless(...)`."""
        yield self.success
        yield self.error_summary() if not self.success else self.raw_output

    def error_summary(self, max_errors: int = 5) -> str:
        """Structured error summary for logging/prompt injection."""
        if not self.errors:
            return self.raw_output[:500] if self.raw_output else "unknown error"
        lines = []
        for err in self.errors[:max_errors]:
            lines.append(str(err))
        if len(self.errors) > max_errors:
            lines.append(f"... and {len(self.errors) - max_errors} more errors")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Error parsing
# ---------------------------------------------------------------------------

# Each pattern: (compiled regex, category, suggestion template)
# Groups expected: file, line, message (in that order where possible)
ERROR_PATTERNS: list[tuple[re.Pattern, str, str]] = [
    (
        re.compile(r"res://([^:]+):(\d+)\s*-\s*Parse Error:\s*(.+)", re.IGNORECASE),
        "parse_error",
        "Check syntax at line {line}. Common issues: missing colon, unmatched brackets, wrong indentation.",
    ),
    (
        re.compile(r"res://([^:]+):(\d+)\s*-\s*.*Node not found:\s*\"?([^\"]+)\"?", re.IGNORECASE),
        "missing_node",
        "Node '{message}' doesn't exist in the scene tree. Check node names and paths.",
    ),
    (
        re.compile(r"res://([^:]+):(\d+)\s*-\s*Invalid call.*Nonexistent function\s+'(\w+)'", re.IGNORECASE),
        "method_error",
        "Function '{message}' doesn't exist on this object. Check method name and class.",
    ),
    (
        re.compile(r"res://([^:]+):(\d+)\s*-\s*.*null instance.*", re.IGNORECASE),
        "null_access",
        "Accessing a property/method on null. Ensure the node exists and is initialized.",
    ),
    (
        re.compile(r"Failed loading resource:\s*res://(.+)", re.IGNORECASE),
        "missing_resource",
        "Resource file doesn't exist on disk. Check the path and ensure the file was created.",
    ),
    (
        re.compile(r"scene/resources/packed_scene.*res://([^:]+).*error", re.IGNORECASE),
        "scene_error",
        "Scene file is malformed. Check .tscn format, ext_resource paths, and node structure.",
    ),
]


def parse_godot_errors(output: str) -> list[GodotError]:
    """Parse raw Godot output into structured GodotError objects."""
    errors = []
    for line in output.splitlines():
        for pattern, category, suggestion_template in ERROR_PATTERNS:
            m = pattern.search(line)
            if m:
                groups = m.groups()
                file_path = groups[0] if len(groups) > 0 else "unknown"
                line_num = int(groups[1]) if len(groups) > 1 and groups[1].isdigit() else 0
                message = groups[2] if len(groups) > 2 else line.strip()

                suggestion = suggestion_template.format(
                    line=line_num, message=message
                )
                errors.append(GodotError(
                    category=category,
                    file=f"res://{file_path}",
                    line=line_num,
                    message=message,
                    suggestion=suggestion,
                ))
                break  # One match per line
    return errors


# ---------------------------------------------------------------------------
# Pre-validation (before launching Godot)
# ---------------------------------------------------------------------------

def pre_validate_gdscript(path: Path) -> list[GodotError]:
    """Quick static checks on a .gd file: balanced brackets, valid preload paths."""
    errors = []
    try:
        content = path.read_text(encoding="utf-8")
        lines = content.splitlines()
    except Exception as e:
        return [GodotError("validation", str(path), 0, f"Cannot read file: {e}")]

    rel_path = str(path)

    # Check balanced brackets/parens
    open_chars = {"(": ")", "[": "]", "{": "}"}
    close_chars = {v: k for k, v in open_chars.items()}
    stack: list[tuple[str, int]] = []

    for i, line in enumerate(lines, 1):
        in_string = False
        str_char = ""
        for ch in line:
            if in_string:
                if ch == str_char:
                    in_string = False
                continue
            if ch == "#":
                break  # Rest of line is a comment
            if ch in ('"', "'"):
                in_string = True
                str_char = ch
                continue
            if ch in open_chars:
                stack.append((ch, i))
            elif ch in close_chars:
                if not stack:
                    errors.append(GodotError(
                        "validation", rel_path, i,
                        f"Unmatched closing '{ch}'",
                        "Check for missing opening bracket/paren.",
                    ))
                elif stack[-1][0] != close_chars[ch]:
                    errors.append(GodotError(
                        "validation", rel_path, i,
                        f"Mismatched bracket: expected '{open_chars[stack[-1][0]]}' but got '{ch}'",
                        f"Opening '{stack[-1][0]}' was at line {stack[-1][1]}.",
                    ))
                    stack.pop()
                else:
                    stack.pop()

    for ch, line_num in stack:
        errors.append(GodotError(
            "validation", rel_path, line_num,
            f"Unclosed '{ch}'",
            "Add the matching closing bracket/paren.",
        ))

    # Check preload() paths exist on disk
    game_root = _find_game_root(path)
    if game_root:
        for i, line in enumerate(lines, 1):
            for m in re.finditer(r'preload\(\s*"(res://[^"]+)"\s*\)', line):
                res_path = m.group(1)
                disk_path = game_root / res_path.removeprefix("res://")
                if not disk_path.exists():
                    errors.append(GodotError(
                        "missing_resource", rel_path, i,
                        f"preload path not found: {res_path}",
                        "Ensure the referenced file exists before preloading.",
                    ))

    return errors


def validate_scene_refs(game_path: Path, files_written: list[str]) -> list[GodotError]:
    """Validate ext_resource paths in .tscn files exist on disk."""
    errors = []

    for filepath in files_written:
        p = Path(filepath)
        if p.suffix != ".tscn":
            continue
        if not p.exists():
            continue

        try:
            content = p.read_text(encoding="utf-8")
        except Exception:
            continue

        for i, line in enumerate(content.splitlines(), 1):
            # Match ext_resource with path=
            m = re.search(r'path\s*=\s*"(res://[^"]+)"', line)
            if m:
                res_path = m.group(1)
                disk_path = game_path / res_path.removeprefix("res://")
                if not disk_path.exists():
                    errors.append(GodotError(
                        "missing_resource", str(p), i,
                        f"ext_resource path not found: {res_path}",
                        "Ensure the referenced script/scene/resource exists.",
                    ))

    return errors


def _find_game_root(path: Path) -> Path | None:
    """Walk up from a file path to find the directory containing project.godot."""
    current = path.parent
    for _ in range(10):
        if (current / "project.godot").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


# ---------------------------------------------------------------------------
# Smoke testing (Phase 2)
# ---------------------------------------------------------------------------

def run_smoke_test(godot_exe: str, project_path: Path, timeout: int = 15) -> "TestResult":
    """Write a temp smoke-test script, run it headless, parse results."""
    smoke_script = project_path / "scripts" / "_smoke_test.gd"
    smoke_code = '''\
extends SceneTree

func _init():
\tvar ok := true

\t# Check main scene loads
\tvar main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
\tif main_scene == "":
\t\tprint("SMOKE_FAIL: No main scene configured")
\t\tok = false
\telse:
\t\tvar packed = load(main_scene)
\t\tif packed == null:
\t\t\tprint("SMOKE_FAIL: Cannot load main scene: " + main_scene)
\t\t\tok = false

\t# Check autoloads exist
\tvar autoloads := []
\tfor prop in ProjectSettings.get_property_list():
\t\tvar name: String = prop["name"]
\t\tif name.begins_with("autoload/"):
\t\t\tautoloads.append(name.trim_prefix("autoload/"))

\tfor al in autoloads:
\t\tif not root.has_node(al):
\t\t\tprint("SMOKE_FAIL: Autoload not found: " + al)
\t\t\tok = false

\tif ok:
\t\tprint("SMOKE_RESULT: OK")
\telse:
\t\tprint("SMOKE_RESULT: FAIL")
\tquit()
'''
    try:
        smoke_script.write_text(smoke_code, encoding="utf-8")

        cmd = [
            godot_exe,
            "--path", str(project_path),
            "--headless",
            "--script", "res://scripts/_smoke_test.gd",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        output = result.stdout + result.stderr

        success = "SMOKE_RESULT: OK" in output
        errors = []
        for line in output.splitlines():
            if line.startswith("SMOKE_FAIL:"):
                errors.append(GodotError(
                    "smoke_test", "smoke_test", 0,
                    line.removeprefix("SMOKE_FAIL:").strip(),
                ))

        return TestResult(success=success, raw_output=output, errors=errors)

    except subprocess.TimeoutExpired:
        return TestResult(success=False, raw_output=f"Smoke test timed out after {timeout}s", errors=[])
    except Exception as e:
        return TestResult(success=False, raw_output=str(e), errors=[])
    finally:
        if smoke_script.exists():
            smoke_script.unlink()


# ---------------------------------------------------------------------------
# Main test function
# ---------------------------------------------------------------------------

def test_headless(
    godot_exe: str,
    project_path: Path,
    timeout: int = 10,
    quit_after: int = 2,
) -> TestResult:
    """Run Godot headless and return a TestResult.

    Backward compatible: `success, output = test_headless(...)` still works.
    """
    cmd = [
        godot_exe,
        "--path", str(project_path),
        "--headless",
        "--quit-after", str(quit_after),
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout + result.stderr
        errors = parse_godot_errors(output)

        # Separate warnings
        warnings = [
            line for line in output.splitlines()
            if "WARNING" in line.upper()
        ]

        if result.returncode == 0 and not errors:
            return TestResult(
                success=True, raw_output=output,
                errors=errors, warnings=warnings,
            )
        else:
            return TestResult(
                success=False,
                raw_output=f"Exit code {result.returncode}\n{output}",
                errors=errors, warnings=warnings,
            )

    except subprocess.TimeoutExpired:
        return TestResult(
            success=False,
            raw_output=f"Godot timed out after {timeout}s (possible infinite loop or crash)",
        )
    except FileNotFoundError:
        return TestResult(
            success=False,
            raw_output=f"Godot executable not found: {godot_exe}",
        )
