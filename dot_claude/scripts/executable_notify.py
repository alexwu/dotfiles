#!/usr/bin/env python3
"""Push notifications for Claude Code events via apprise."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any

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


def _ghostty_focused_cwd() -> str:
    """Get the working directory of Ghostty's focused terminal via AppleScript."""
    script = """\
tell application "Ghostty"
    if not frontmost then return ""
    set focusedWindow to front window
    set activeTab to selected tab of focusedWindow
    set activeTerm to focused terminal of activeTab
    return working directory of activeTerm
end tell"""
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=2,
        )
        return result.stdout.strip()
    except (subprocess.SubprocessError, OSError):
        return ""


def _is_zellij_pane_focused() -> bool | None:
    """Check if our Zellij pane is focused on the active tab. None if not in Zellij."""
    pane_id = os.environ.get("ZELLIJ_PANE_ID")
    if pane_id is None:
        return None
    try:
        tab_result, panes_result = (
            subprocess.run(
                cmd, capture_output=True, text=True, timeout=2,
            )
            for cmd in (
                ["zellij", "action", "current-tab-info"],
                ["zellij", "action", "list-panes", "--state", "--tab", "--json"],
            )
        )
        active_tab_id = None
        for line in tab_result.stdout.strip().split("\n"):
            if line.startswith("id:"):
                active_tab_id = int(line.split(":")[1].strip())
                break
        if active_tab_id is None:
            return None

        for pane in json.loads(panes_result.stdout):
            if pane.get("id") == int(pane_id) and not pane.get("is_plugin"):
                return pane.get("is_focused", False) and pane.get("tab_id") == active_tab_id
        return False
    except (subprocess.SubprocessError, OSError, json.JSONDecodeError, ValueError):
        return None


def is_this_terminal_focused() -> bool:
    """Check if the specific terminal running this session is focused."""
    # Zellij pane check — if our pane isn't focused, no need to check the terminal app
    zellij_focused = _is_zellij_pane_focused()
    if zellij_focused is False:
        return False

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

        # For ghostty: match focused terminal's working directory via AppleScript
        bundle = os.environ.get("__CFBundleIdentifier", "")
        if bundle == "com.mitchellh.ghostty":
            if focused_app != "ghostty":
                return False
            return _ghostty_focused_cwd() == os.getcwd()

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


def _zellij_tab_for_pane(pane_id: str) -> int | None:
    """Get the tab ID for a Zellij pane."""
    try:
        result = subprocess.run(
            ["zellij", "action", "list-panes", "--tab", "--json"],
            capture_output=True, text=True, timeout=2,
        )
        for pane in json.loads(result.stdout):
            if pane.get("id") == int(pane_id) and not pane.get("is_plugin"):
                return pane.get("tab_id")
    except (subprocess.SubprocessError, OSError, json.JSONDecodeError, ValueError):
        pass
    return None


def _build_local_notify_cmd(
    title: str, body: str, subtitle: str,
) -> list[list[str]]:
    """Build the local notification command(s). Uses terminal-notifier with
    click-to-focus when in Zellij, falls back to apprise otherwise."""
    apprise_title = f"{title} — {subtitle}" if subtitle else title
    apprise_cmd = ["apprise", "-t", apprise_title, "-b", body, "-i", "markdown"]

    pane_id = os.environ.get("ZELLIJ_PANE_ID")
    if pane_id is None:
        return [apprise_cmd]

    tab_id = _zellij_tab_for_pane(pane_id)
    cmd: list[str] = ["terminal-notifier", "-title", title, "-message", body]
    if subtitle:
        cmd += ["-subtitle", subtitle]
    bundle = os.environ.get("__CFBundleIdentifier", "")
    if bundle:
        cmd += ["-activate", bundle]
    if tab_id is not None:
        session = os.environ.get("ZELLIJ_SESSION_NAME", "")
        socket_dir = os.environ.get("ZELLIJ_SOCKET_DIR", "/tmp/zellij")
        zellij = shutil.which("zellij") or "zellij"
        script = (
            f"#!/bin/sh\n"
            f"export ZELLIJ_SOCKET_DIR={socket_dir}\n"
            f"{zellij} -s {session} action go-to-tab-by-id {tab_id}\n"
            f"{zellij} -s {session} action focus-pane-id terminal_{pane_id}\n"
        )
        fd, path = tempfile.mkstemp(prefix="zellij-focus-", suffix=".sh")
        os.write(fd, script.encode())
        os.close(fd)
        os.chmod(path, 0o755)
        cmd += ["-execute", path]
    return [cmd, apprise_cmd]


def send(
    title: str,
    body: str,
    project: str,
    *,
    subtitle: str = "",
    thread_id: str = "",
    priority: str = "normal",
    debug: bool = False,
) -> None:
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

    local_procs = [
        subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for cmd in _build_local_notify_cmd(title, body, subtitle)
    ]

    brrr_url = os.environ.get("BRRR_WEBHOOK_URL")
    brrr_proc = None
    if brrr_url:
        brrr_payload: dict[str, Any] = {
            "title": title,
            "message": body,
            "thread_id": thread_id or project,
            "interruption_level": "time-sensitive" if priority == "high" else "active",
            "image_url": "https://cdn.lulu.sh/images/notify/claude/luna-sfw-gemini-generated.png",
        }
        if subtitle:
            brrr_payload["subtitle"] = subtitle
        payload = json.dumps(brrr_payload).encode()
        brrr_proc = subprocess.Popen(
            ["curl", "-s", "-X", "POST", brrr_url,
             "-H", "Content-Type: application/json",
             "--data-binary", "@-"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if brrr_proc.stdin:
            brrr_proc.stdin.write(payload)
            brrr_proc.stdin.close()

    local_rcs = [p.wait() for p in local_procs]
    brrr_rc = brrr_proc.wait() if brrr_proc else None

    _log(f"SENT {title} (local rc={local_rcs}, brrr rc={brrr_rc})")
    record_notification(project)


def extract_question(tool_input: dict[str, Any]) -> str:
    """Extract question text from AskUserQuestion input, checking multiple fields."""
    questions = tool_input.get("questions", [])
    if questions:
        first = questions[0]
        for key in ("question", "prompt", "message", "text"):
            if val := first.get(key):
                return str(val)
    # Fallback: check top-level fields
    for key in ("question", "prompt", "message", "text"):
        if val := tool_input.get(key):
            return str(val)
    return "Question"


def extract_options(tool_input: dict[str, Any]) -> list[str]:
    """Extract option labels from AskUserQuestion input."""
    questions = tool_input.get("questions", [])
    if not questions:
        return []
    options = questions[0].get("options", [])
    return [o.get("label", "") for o in options[:4] if isinstance(o, dict)]


def handle_stop(data: dict[str, Any]) -> None:
    cwd = os.path.basename(data.get("cwd", ""))
    session = data.get("session_id", "")
    message = data.get("last_assistant_message", "Task completed")
    # Strip action beats / italics for cleaner notifications
    lines = [
        line for line in message.split("\n")
        if line.strip() and not line.strip().startswith("*")
    ]
    body = "\n".join(lines) if lines else "Task completed"
    send("✅ Task Complete", body, cwd, subtitle=cwd, thread_id=session)


def handle_pre_tool_use(data: dict[str, Any]) -> None:
    tool = data.get("tool_name", "")
    cwd = os.path.basename(data.get("cwd", ""))
    session = data.get("session_id", "")

    if tool == "AskUserQuestion":
        tool_input = data.get("tool_input", {})
        question = extract_question(tool_input)
        options = extract_options(tool_input)
        parts = [question]
        if options:
            parts.append(f"→ {' | '.join(options)}")
        send(
            "❓ Question", "\n".join(parts), cwd,
            subtitle=cwd, thread_id=session, priority="high",
        )


NOTIFICATION_TITLES: dict[str, str] = {
    "permission_prompt": "🔐 Needs Approval",
    "idle_prompt": "⏸️ Waiting For Next Steps",
    "auth_success": "🔑 Auth Complete",
    "elicitation_dialog": "📋 Input Needed",
}


def handle_notification(data: dict[str, Any]) -> None:
    cwd = os.path.basename(data.get("cwd", ""))
    session = data.get("session_id", "")
    notification_type = data.get("notification_type", "")
    title = NOTIFICATION_TITLES.get(notification_type, "⏳ Waiting")
    message = data.get("message", "Waiting for input")
    send(
        title, message, cwd,
        subtitle=cwd, thread_id=session, priority="high",
    )


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
