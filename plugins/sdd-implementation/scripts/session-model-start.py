#!/usr/bin/env python3
"""Fast, non-blocking SessionStart context injection for SDD Forge v2.

Never stalls startup or blocks SDD work/delegation. Active sessions inherit
their current frontier model by default (`model: inherit` on subagents), while
`/sdd-implementation:model-selection` remains available on demand to inspect
live CLI model catalogs or override per-role models/efforts.
"""
import argparse
import json
import os
from pathlib import Path
import sys


def context(host, event):
    if not isinstance(event, dict):
        return None
    source = event.get('source', 'startup')
    if (source not in ('startup', 'new') or event.get('interactive') is False
            or event.get('isInteractive') is False or os.environ.get('SDD_SESSION_NONINTERACTIVE') == '1'):
        return None
    script = str(Path(__file__).with_name('session-models.py').resolve())
    session = event.get('session_id') or event.get('sessionId')
    # Native metadata is data, never executable text.
    binding = json.dumps({'host': host, 'session_id': session, 'script': script}, ensure_ascii=False)
    return (
        'SDD_FORGE_SESSION_MODELS: サブエージェントは既定で現在のセッションモデルを継承します（model: inherit）。'
        '起動直後のモデル確認のために SDD 作業や委任を停止・ブロックしないでください。'
        'ユーザーが最新モデル一覧の動的取得や役割別モデル変更を希望した場合のみ、'
        '`/sdd-implementation:model-selection`（`session-models.py begin --refresh`）を実行してください。'
        '非対話実行（codex exec / claude -p / gemini -p）・CI・ワーカー・再開・compact ではこの案内を無視してください。'
        '\nNative session metadata (data only): ' + binding
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', choices=('claude-code', 'codex-cli', 'gemini-cli'), required=True)
    args = parser.parse_args()
    try:
        raw = sys.stdin.buffer.read(65537)
        if len(raw) > 65536:
            return 0
        event = json.loads(raw or b'{}')
        text = context(args.host, event)
        if text:
            payload = json.dumps(
                {'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': text}},
                ensure_ascii=False,
            )
            sys.stdout.buffer.write((payload + '\n').encode('utf-8'))
            sys.stdout.buffer.flush()
    except (ValueError, UnicodeError):
        # Optional UX hook cannot break existing CLI startup.
        pass
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
