#!/usr/bin/env python3
"""Apply a confirmed session choice to the unchanged panelist collection boundary."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('panelist_session_models', HERE / 'session-models.py')
models = importlib.util.module_from_spec(spec)
spec.loader.exec_module(models)


def command(selected, vendor, shell, arguments, powershell="pwsh"):
    if selected['host'] != ('codex-cli' if vendor == 'gpt' else 'gemini-cli'):
        raise models.SelectionError('panelistのCLIがセッション設定と一致しません。')
    if any(x in arguments for x in ('--model-controls', '--model-controls-sha256', '--run-id', '--session-id')):
        raise models.SelectionError('管理された起動ではsession request経由で既存の起動制御を使ってください。')
    rest = list(arguments)
    for flag, expected in (('--model', selected['model']), ('--effort', selected['effort'])):
        positions = [i for i, arg in enumerate(rest) if arg == flag]
        if len(positions) > 1 or positions and (positions[0] + 1 >= len(rest) or rest[positions[0] + 1] != expected):
            raise models.SelectionError('既存の明示モデル・推論設定がセッション設定と競合しています。')
        if positions:
            del rest[positions[0]:positions[0] + 2]
    if vendor == 'gemini' and selected['effort'] is not None:
        raise models.SelectionError('Gemini panelistに対応する推論設定の起動引数がありません。')
    owner = HERE.parent
    quality = (owner.parent / 'sdd-quality-loop' if owner.name == 'sdd-implementation' else
               owner.parent.parent / 'sdd-quality-loop' / owner.name)
    path = quality / 'scripts' / ('run-panelist-' + vendor + ('.sh' if shell == 'bash' else '.ps1'))
    if not path.is_file() or path.is_symlink():
        raise models.SelectionError('同じリリースのpanelist収集スクリプトが見つかりません。')
    argv = ['bash', str(path)] if shell == 'bash' else [powershell, '-NoProfile', '-File', str(path)]
    argv += rest + ['--model', selected['model']]
    if selected['effort'] is not None:
        argv += ['--effort', selected['effort']]
    return argv


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--vendor', choices=('gpt', 'gemini'), required=True)
    parser.add_argument('--shell', choices=('bash', 'powershell'), required=True)
    parser.add_argument('--model-session', required=True)
    parser.add_argument('--powershell', default='pwsh')
    parser.add_argument('--model-config-home', type=Path)
    # Wrapper-owned controls must not be replaced by forwarded collector arguments.
    for flag in ('--vendor', '--shell', '--powershell', '--model-session', '--model-config-home'):
        if sum(arg == flag or arg.startswith(flag + '=') for arg in sys.argv[1:]) > 1:
            parser.error('duplicate session adapter control: ' + flag)
    args, rest = parser.parse_known_args()
    try:
        store = models.Store(Path.cwd(), args.model_config_home)
        selected = models.selection(store, args.model_session, 'panelist-' + args.vendor)
        result = subprocess.run(command(selected, args.vendor, args.shell, rest, args.powershell))
        if result.returncode:
            print('選択したpanelistの起動に失敗しました。停止し、モデルを再選択してください。', file=sys.stderr)
        return result.returncode
    except (models.SelectionError, OSError, ValueError) as exc:
        print('SESSION_MODEL_SELECTION_REQUIRED: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
