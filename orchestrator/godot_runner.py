"""Run Godot headless to test the project, with structured error parsing and video recording."""

import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class RecordingResult:
    success: bool
    video_path: str = ""
    raw_output: str = ""
    error: str = ""


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
    # Godot 4.6 SCRIPT ERROR format — file:line is on the *next* line ("at: ..."),
    # but "Failed to load script" gives us file + message on one line.
    (
        re.compile(r'Failed to load script "res://([^"]+)".*error\s+"([^"]+)"', re.IGNORECASE),
        "script_load_error",
        "Script failed to load: {message}. Fix parse errors in this file — downstream scripts depending on its class_name will also break.",
    ),
]


# Godot 4.6 emits multi-line SCRIPT ERROR blocks:
#   SCRIPT ERROR: Parse Error: Could not find type "Foo" in the current scope.
#      at: GDScript::reload (res://scripts/bar.gd:3)
# The two-pass parser below correlates them into proper GodotError objects.

_SCRIPT_ERROR_RE = re.compile(r"SCRIPT ERROR:\s*(.+)")
_AT_LINE_RE = re.compile(r"at:.*\(res://([^:)]+):(\d+)\)")


def _parse_script_error_blocks(output: str) -> list[GodotError]:
    """Parse multi-line SCRIPT ERROR blocks that the single-line patterns miss."""
    errors = []
    pending_message: str | None = None

    for line in output.splitlines():
        m = _SCRIPT_ERROR_RE.search(line)
        if m:
            pending_message = m.group(1).strip()
            continue

        if pending_message is not None:
            m2 = _AT_LINE_RE.search(line)
            if m2:
                errors.append(GodotError(
                    category="script_error",
                    file=f"res://{m2.group(1)}",
                    line=int(m2.group(2)),
                    message=pending_message,
                    suggestion=f"Fix: {pending_message}",
                ))
                pending_message = None
            elif line.strip():
                # Not an "at:" line and not blank — drop the pending message
                pending_message = None

    return errors


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

    # Two-pass: correlate multi-line SCRIPT ERROR blocks (Godot 4.6 format)
    block_errors = _parse_script_error_blocks(output)
    # Deduplicate — keep block errors that aren't already captured by file+line
    seen = {(e.file, e.line) for e in errors}
    for be in block_errors:
        if (be.file, be.line) not in seen:
            errors.append(be)
            seen.add((be.file, be.line))

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

def capture_baseline_errors(godot_exe: str, project_path: Path, timeout: int = 10) -> set[tuple[str, int, str]]:
    """Run Godot headless and return the set of pre-existing errors as (file, line, message) tuples."""
    cmd = [
        godot_exe,
        "--path", str(project_path),
        "--headless",
        "--quit-after", "1",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        output = result.stdout + result.stderr
        errors = parse_godot_errors(output)
        return {(e.file, e.line, e.message) for e in errors}
    except Exception:
        return set()


def test_headless(
    godot_exe: str,
    project_path: Path,
    timeout: int = 10,
    quit_after: int = 2,
    baseline_errors: set[tuple[str, int, str]] | None = None,
) -> TestResult:
    """Run Godot headless and return a TestResult.

    If baseline_errors is provided, only errors NOT in the baseline are treated
    as failures. This prevents pre-existing errors from blocking new changes.
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

        # Filter out pre-existing errors if baseline provided
        if baseline_errors:
            new_errors = [e for e in errors if (e.file, e.line, e.message) not in baseline_errors]
        else:
            new_errors = errors

        # Separate warnings
        warnings = [
            line for line in output.splitlines()
            if "WARNING" in line.upper()
        ]

        if result.returncode == 0 and not new_errors:
            return TestResult(
                success=True, raw_output=output,
                errors=new_errors, warnings=warnings,
            )
        else:
            return TestResult(
                success=False,
                raw_output=f"Exit code {result.returncode}\n{output}",
                errors=new_errors, warnings=warnings,
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


# ---------------------------------------------------------------------------
# Video recording (Godot Movie Maker)
# ---------------------------------------------------------------------------

def _convert_to_mp4(avi_path: Path, mp4_path: Path, timeout: int = 30) -> bool:
    """Convert AVI to MP4 using FFmpeg. Returns True on success."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("  FFmpeg not found — skipping AVI→MP4 conversion.")
        return False

    cmd = [
        ffmpeg, "-y",
        "-i", str(avi_path),
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-an",  # No audio (Godot Movie Maker doesn't record audio)
        str(mp4_path),
    ]
    try:
        subprocess.run(cmd, capture_output=True, timeout=timeout, check=True)
        return mp4_path.exists() and mp4_path.stat().st_size > 0
    except Exception as e:
        print(f"  FFmpeg conversion failed: {e}")
        return False


def _detect_main_scene(project_path: Path) -> str:
    """Read main scene from project.godot. Returns empty string if not found."""
    project_file = project_path / "project.godot"
    if not project_file.exists():
        return ""
    text = project_file.read_text(encoding="utf-8")
    m = re.search(r'run/main_scene\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else ""


def _looks_like_project_manager(output: str) -> bool:
    """Check if Godot output suggests it opened the project manager instead of a game scene.

    This catches cases where project.godot is corrupted (parse errors cause Godot
    to fall back to the project manager, which shows local file paths).
    """
    indicators = [
        "project manager",
        "ProjectManager",
        "project_manager",
        "Scanning projects",
        "No main scene",
        "Main scene is not defined",
        # project.godot parse errors cause fallback to project manager
        "Error parsing",
        "Couldn't load file",
        "error code 43",
    ]
    output_lower = output.lower()
    return any(ind.lower() in output_lower for ind in indicators)


def record_gameplay(
    godot_exe: str,
    project_path: Path,
    output_path: Path,
    duration: int = 10,
    fps: int = 30,
    timeout: int = 30,
) -> RecordingResult:
    """Record gameplay using Godot's Movie Maker mode.

    Movie Maker requires a visible window (no --headless). The game runs for
    `duration` seconds at a fixed framerate and writes an .avi file, then
    converts to MP4 (for Twitter compatibility).

    SAFETY: If the main scene cannot be determined, recording is SKIPPED entirely
    to prevent recording the Godot project manager (which shows file paths).
    """
    # CRITICAL: Detect main scene FIRST. If we can't find it, do NOT record.
    # Without a valid main scene, Godot opens the project manager which exposes
    # local file paths — these must never be recorded or posted to Twitter.
    main_scene = _detect_main_scene(project_path)
    if not main_scene:
        return RecordingResult(
            success=False,
            error="No main scene found in project.godot — skipping recording to avoid exposing project manager",
        )

    # Verify the main scene file actually exists on disk
    scene_disk_path = project_path / main_scene.removeprefix("res://")
    if not scene_disk_path.exists():
        return RecordingResult(
            success=False,
            error=f"Main scene {main_scene} not found on disk — skipping recording",
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Godot always outputs AVI; we'll convert to MP4 after
    avi_path = output_path.with_suffix(".avi")
    mp4_path = output_path.with_suffix(".mp4")

    # With --write-movie, --quit-after counts FRAMES not seconds
    total_frames = duration * fps

    cmd = [
        godot_exe,
        "--path", str(project_path),
        "--scene", main_scene,
        "--write-movie", str(avi_path),
        "--fixed-fps", str(fps),
        "--quit-after", str(total_frames),
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout + result.stderr

        # SAFETY: If Godot opened the project manager, discard everything
        if _looks_like_project_manager(output):
            # Delete any video file that was created — it shows the project manager
            for path in (avi_path, mp4_path):
                if path.exists():
                    path.unlink()
            return RecordingResult(
                success=False,
                raw_output=output,
                error="Godot opened project manager instead of game scene — video discarded",
            )

        if not (avi_path.exists() and avi_path.stat().st_size > 0):
            return RecordingResult(
                success=False,
                raw_output=output,
                error=f"Recording finished but no video file at {avi_path}",
            )

        # Convert AVI → MP4 for Twitter compatibility
        if _convert_to_mp4(avi_path, mp4_path):
            avi_path.unlink()  # Clean up AVI
            return RecordingResult(
                success=True,
                video_path=str(mp4_path),
                raw_output=output,
            )
        else:
            # Fall back to AVI if conversion fails
            return RecordingResult(
                success=True,
                video_path=str(avi_path),
                raw_output=output,
            )

    except subprocess.TimeoutExpired:
        if avi_path.exists() and avi_path.stat().st_size > 0:
            if _convert_to_mp4(avi_path, mp4_path):
                avi_path.unlink()
                return RecordingResult(
                    success=True,
                    video_path=str(mp4_path),
                    raw_output=f"Timed out after {timeout}s but video file exists",
                )
            return RecordingResult(
                success=True,
                video_path=str(avi_path),
                raw_output=f"Timed out after {timeout}s but video file exists",
            )
        return RecordingResult(
            success=False,
            error=f"Recording timed out after {timeout}s with no output",
        )
    except FileNotFoundError:
        return RecordingResult(
            success=False,
            error=f"Godot executable not found: {godot_exe}",
        )
    except Exception as e:
        return RecordingResult(
            success=False,
            error=str(e),
        )
