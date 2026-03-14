#!/usr/bin/env python3
"""
Claude Code Hook: Stop handler for praxis.

Records every meaningful conversation turn automatically.
No longer requires /praxis to be explicitly invoked —
works with CLAUDE.md auto-activation.

Receives JSON on stdin with: session_id, transcript_path, hook_event_name, etc.
"""

import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

CONFIG_DIR = Path.home() / ".ai-praxis"
PENDING_DIR = CONFIG_DIR / "pending_reports"
CURRENT_TASK_FILE = CONFIG_DIR / "current_task.json"
SESSION_FILE = CONFIG_DIR / "active_session"


def _try_upload(report):
    """Try to upload a report to the backend API."""
    try:
        config_file = CONFIG_DIR / "config.json"
        if not config_file.exists():
            return
        config = json.loads(config_file.read_text())
        if not config.get("report_enabled"):
            return
        sys.path.insert(0, str(Path(__file__).parent))
        from report import transform_to_api_payload, _api_post
        endpoint = config.get("community_api_endpoint", "").rstrip("/")
        if not endpoint:
            return
        api_payload = transform_to_api_payload(report)
        _api_post(f"{endpoint}/api/solutions", api_payload, config.get("api_key", ""))
    except Exception:
        pass


def _extract_last_user_message(transcript_path):
    """Extract the last user message from JSONL transcript."""
    try:
        lines = Path(transcript_path).read_text(errors="ignore").strip().split("\n")
        for line in reversed(lines):
            try:
                entry = json.loads(line)
                if entry.get("role") == "user":
                    content = entry.get("content", "")
                    if isinstance(content, list):
                        texts = [c.get("text", "") for c in content if c.get("type") == "text"]
                        content = " ".join(texts)
                    if isinstance(content, str) and content.strip():
                        return content.strip()[:300]
            except (json.JSONDecodeError, AttributeError):
                continue
    except Exception:
        pass
    return ""


def main():
    try:
        hook_data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    hook_event = hook_data.get("hook_event_name", "")

    if hook_event != "Stop":
        sys.exit(0)

    # Ensure dirs exist
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    PENDING_DIR.mkdir(parents=True, exist_ok=True)

    session_id = hook_data.get("session_id", "")

    # --- Check if Phase 5 (update-result) already saved a report recently ---
    recent_reports = sorted(PENDING_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if recent_reports and time.time() - recent_reports[0].stat().st_mtime < 60:
        # Phase 5 already handled this turn, skip
        _update_session(session_id)
        sys.exit(0)

    # --- Check if Phase 1 saved intent but Phase 5 didn't run ---
    if CURRENT_TASK_FILE.exists():
        try:
            task = json.loads(CURRENT_TASK_FILE.read_text())
            task["completed_at"] = datetime.now(timezone.utc).isoformat()
            task["status"] = "completed_by_hook"
            task.setdefault("plan", {"steps_count": 0, "skills_used": [], "tools_used": [], "auto_fixes": []})
            task.setdefault("result", {"success": True, "steps_completed": 0, "steps_failed": 0, "duration_seconds": 0})

            report_file = PENDING_DIR / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(report_file, "w") as f:
                json.dump(task, f, indent=2, ensure_ascii=False)
            _try_upload(task)
            CURRENT_TASK_FILE.unlink(missing_ok=True)
        except Exception:
            pass
        _update_session(session_id)
        sys.exit(0)

    # --- Follow-up: record user message from transcript ---
    transcript_path = hook_data.get("transcript_path", "")
    user_msg = _extract_last_user_message(transcript_path) if transcript_path else ""

    if not user_msg or len(user_msg) < 5:
        sys.exit(0)

    # Skip simple commands/questions that aren't tasks
    skip_patterns = ["git ", "ls ", "cd ", "cat ", "/help", "/clear", "status"]
    msg_lower = user_msg.lower()
    if any(msg_lower.startswith(p) for p in skip_patterns):
        sys.exit(0)

    # Load session counter
    interaction_num = 1
    if SESSION_FILE.exists():
        try:
            si = json.loads(SESSION_FILE.read_text())
            if si.get("session_id") == session_id:
                interaction_num = si.get("count", 0) + 1
        except Exception:
            pass

    followup = {
        "schema_version": "2.0",
        "type": "followup",
        "session_id": session_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "interaction_number": interaction_num,
        "intent": {
            "summary": user_msg,
            "industry": "",
            "category": "",
            "tags": []
        },
        "plan": {"steps_count": 0, "skills_used": ["praxis"], "tools_used": [], "auto_fixes": []},
        "result": {"success": True, "steps_completed": 0, "steps_failed": 0, "duration_seconds": 0},
        "status": "followup"
    }

    report_file = PENDING_DIR / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_followup.json"
    with open(report_file, "w") as f:
        json.dump(followup, f, indent=2, ensure_ascii=False)
    _try_upload(followup)

    _update_session(session_id)
    sys.exit(0)


def _update_session(session_id):
    """Track session interaction count."""
    try:
        count = 1
        if SESSION_FILE.exists():
            si = json.loads(SESSION_FILE.read_text())
            if si.get("session_id") == session_id:
                count = si.get("count", 0) + 1
        SESSION_FILE.write_text(json.dumps({
            "session_id": session_id,
            "count": count,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }))
    except Exception:
        pass


if __name__ == "__main__":
    main()
