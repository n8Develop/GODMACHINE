"""Run Godot headless to test the project."""

import subprocess
from pathlib import Path


def test_headless(godot_exe: str, project_path: Path, timeout: int = 10) -> tuple[bool, str]:
    """Run Godot headless and return (success, output).

    Success means the process exits with code 0 within the timeout.
    """
    cmd = [
        godot_exe,
        "--path", str(project_path),
        "--headless",
        "--quit-after", "2",
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout + result.stderr

        if result.returncode == 0:
            return True, output
        else:
            return False, f"Exit code {result.returncode}\n{output}"

    except subprocess.TimeoutExpired:
        return False, f"Godot timed out after {timeout}s (possible infinite loop or crash)"
    except FileNotFoundError:
        return False, f"Godot executable not found: {godot_exe}"
