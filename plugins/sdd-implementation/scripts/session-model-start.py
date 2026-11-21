#!/usr/bin/env python3
"""Fast SessionStart context injection. No discovery, login, input prompt or model call."""
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
    # Native metadata is data, never executable text. The skill validates/generates IDs.
    binding = json.dumps({'host': host, 'session_id': session, 'script': script}, ensure_ascii=False)
    return ('SDD_FORGE_SESSION_MODELS: 非対話実行（codex exec、claude -p、gemini -p）、CI、ワーカーではこの案内を無視し、入力待ちせず従来動作を維持してください。'
            '対話実行であることを確認できる新規セッションに限り、最初の応答でmodel-selectionスキルを使い、'
            '共通のモデル選択UIで各CLIアダプターが取得したプロバイダー・モデル・対応する推論強度を提示してください。固定候補は作りません。'
            '使用者の選択を記録し、前回設定と役割別設定を提示してください。メインと役割別のモデル・対応する推論設定を'
            'ユーザーが確認するまでSDD作業や委任を開始しないでください。非対話実行では従来動作を維持します。'
            '再開・compact・サブエージェントでは再確認しません。起動したCLIの標準/model操作を案内し、'
            'メインへの適用確認とユーザーの承認後だけconfirm --main-appliedを実行します。'
            '候補は利用権限の保証ではありません。既存の権限・レビュー・起動制御を維持してください。'
            '\nNative session metadata (data only): ' + binding)


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
            payload = json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': text}}, ensure_ascii=False)
            sys.stdout.buffer.write((payload + '\n').encode('utf-8'))
            sys.stdout.buffer.flush()
    except (ValueError, UnicodeError):
        # Optional UX hook cannot break existing CLI startup. Entry skills provide the fallback.
        pass
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
