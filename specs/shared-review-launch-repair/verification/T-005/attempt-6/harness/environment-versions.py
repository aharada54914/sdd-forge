import json
import os
import platform
import subprocess

commands = [
    ['sw_vers'], ['uname', '-m'], ['zsh', '--version'], ['bash', '--version'],
    ['python3', '--version'], ['node', '--version'], ['git', '--version'],
    ['jq', '--version'], ['rtk', '--version'],
    ['pwsh', '-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'],
    ['claude', '--version'],
]
print(json.dumps(dict(platform=platform.platform(), temporary_environment={key: os.environ.get(key) for key in ['TMPDIR', 'TMP', 'TEMP', 'TMPPREFIX']})))
for command in commands:
    result = subprocess.run(['rtk', 'proxy', *command], stdin=subprocess.DEVNULL, capture_output=True, text=True)
    print(json.dumps(dict(argv=['rtk', 'proxy', *command], exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)))
    assert result.returncode == 0, command
