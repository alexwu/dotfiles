#!/usr/bin/env python3
"""Push notifications for Claude Code events via apprise."""

import hashlib
import json
import os
import subprocess
import sys
import time

RATE_LIMIT_SECONDS = 10

def get_rate_limit_file(project: str) -> str:
    safe_name = hashlib.md5(project.encode()).hexdigest()[:8]
    return f"/tmp/ntfy-claude-{safe_name}.last"


def should_rate_limit(project: str) -> bool:
    rate_file = get_rate_limit_file(project)
    try:
        if os.path.exists(rate_file):
            last_time = float(open(rate_file).read().strip())
            if time.time() - last_time < RATE_LIMIT_SECONDS:
                return True
    except (ValueError, OSError):
        pass
    return False


def record_notification(project: str) -> None:
    try:
        with open(get_rate_limit_file(project), "w") as f:
            f.write(str(time.time()))
    except OSError:
        pass


def get_terminal_pid() -> int | None:
    """Get the PID of the terminal running this session."""
    bundle = os.environ.get("__CFBundleIdentifier", "")

    if bundle == "net.kovidgoyal.kitty":
        pid = os.environ.get("KITTY_PID")
        return int(pid) if pid else None

    if bundle == "com.github.wez.wezterm":
        try:
            result = subprocess.run(
                ["wezterm", "cli", "list-clients", "--format", "json"],
                capture_output=True,
                text=True,
            )
            clients = json.loads(result.stdout)
            if clients:
                return clients[0].get("pid")
        except (subprocess.SubprocessError, OSError, json.JSONDecodeError):
            pass
        return None

    # Unknown terminal — no PID available
    return None


def is_this_terminal_focused() -> bool:
    """Check if the specific terminal running this session is focused."""
    try:
        result = subprocess.run(
            ["aerospace", "list-windows", "--focused", "--json",
             "--format", "%{app-name}%{tab}%{app-pid}"],
            capture_output=True,
            text=True,
        )
        windows = json.loads(result.stdout)
        if not windows:
            return False

        focused_app = windows[0].get("app-name", "")
        focused_pid = windows[0].get("app-pid")

        # For ghostty: just check if any ghostty window is focused
        bundle = os.environ.get("__CFBundleIdentifier", "")
        if bundle == "com.mitchellh.ghostty":
            return focused_app == "ghostty"

        # For kitty/wezterm: match the exact PID
        our_pid = get_terminal_pid()
        if our_pid is not None:
            return focused_pid == our_pid

        return False
    except (subprocess.SubprocessError, OSError, json.JSONDecodeError):
        return False


def is_system_idle(threshold: int = 300) -> bool:
    """Check if user has been idle for threshold seconds."""
    try:
        result = subprocess.run(
            ["ioreg", "-c", "IOHIDSystem"],
            capture_output=True,
            text=True,
        )
        for line in result.stdout.split("\n"):
            if "HIDIdleTime" in line:
                idle_ns = int(line.split("=")[1].strip())
                return (idle_ns / 1_000_000_000) > threshold
    except (subprocess.SubprocessError, OSError, ValueError, IndexError):
        pass
    return False


def send(title: str, body: str, project: str, *, debug: bool = False) -> None:
    log = os.path.expanduser("~/.claude/scripts/notify.log") if debug else None

    def _log(msg: str) -> None:
        if log:
            with open(log, "a") as f:
                f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")

    if should_rate_limit(project):
        _log(f"SUPPRESSED (rate limit) {title}")
        return

    focused = is_this_terminal_focused()
    idle = is_system_idle()
    _log(f"focused={focused} idle={idle}")

    if focused and not idle:
        _log(f"SUPPRESSED (terminal focused) {title}")
        return

    result = subprocess.run(
        ["apprise", "-t", title, "-b", body],
        capture_output=True,
        text=True,
    )
    _log(f"SENT {title} (apprise rc={result.returncode})")
    record_notification(project)


def handle_stop(data: dict) -> None:
    cwd = os.path.basename(data.get("cwd", ""))
    message = data.get("last_assistant_message", "Task completed")
    # Strip action beats / italics for cleaner notifications
    lines = [
        line for line in message.split("\n")
        if line.strip() and not line.strip().startswith("*")
    ]
    body = "\n".join(lines)[:300] if lines else "Task completed"
    send(f"✅ {cwd}", body, cwd)


def handle_pre_tool_use(data: dict) -> None:
    tool = data.get("tool_name", "")
    cwd = os.path.basename(data.get("cwd", ""))

    if tool == "AskUserQuestion":
        questions = data.get("tool_input", {}).get("questions", [])
        question = (
            questions[0].get("question", "Question") if questions else "Question"
        )
        options = questions[0].get("options", []) if questions else []
        parts = [question[:200]]
        if options:
            opts = " | ".join(o.get("label", "") for o in options[:4])
            parts.append(f"→ {opts}")
        send(f"❓ {cwd}", "\n".join(parts), cwd)


def handle_notification(data: dict) -> None:
    cwd = os.path.basename(data.get("cwd", ""))
    message = data.get("message", "Waiting for input")
    send(f"⏳ {cwd}", message[:200], cwd)


def main() -> None:
    if len(sys.argv) < 2:
        return

    event = sys.argv[1]
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        return

    handlers = {
        "Stop": handle_stop,
        "PreToolUse": handle_pre_tool_use,
        "Notification": handle_notification,
    }

    handler = handlers.get(event)
    if handler:
        handler(data)


if __name__ == "__main__":
    main()
