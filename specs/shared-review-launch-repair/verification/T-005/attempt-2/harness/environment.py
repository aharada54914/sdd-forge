import json
import platform
from pathlib import Path
import subprocess
import sys

commands = [['rtk', 'proxy', 'bash', '--version'],
            ['rtk', 'proxy', 'pwsh', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'],
            ['rtk', 'proxy', 'node', '--version'], ['rtk', 'proxy', 'jq', '--version'],
            ['rtk', '--version']]
print(json.dumps(dict(platform=platform.platform(), python=sys.version, executable=sys.executable)))
for command in commands:
    result = subprocess.run(command, text=True, capture_output=True)
    print(json.dumps(dict(command=command, returncode=result.returncode,
                          stdout=result.stdout, stderr=result.stderr)))
    assert result.returncode == 0
package = Path('mcp/ci-mcp/node_modules/ajv/package.json')
print(json.dumps(dict(ajv_pinned_package=str(package), version=json.loads(package.read_text())['version'])))
