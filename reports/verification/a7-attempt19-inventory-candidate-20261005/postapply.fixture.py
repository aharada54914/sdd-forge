"""Run the existing isolated inventory cases against the exact applied helper."""
from pathlib import Path

source = Path(__file__).with_name('inventory.fixture.py')
text = source.read_text()
old = """    applied = subprocess.run(['git', 'apply', str(PATCH)], cwd=root,
                             text=True, capture_output=True, check=False)
    assert applied.returncode == 0, applied.stderr
"""
new = """    assert hashlib.sha256((root / HELPER).read_bytes()).hexdigest() == '0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de'
"""
assert text.count(old) == 1
exec(compile(text.replace(old, new), str(source), 'exec'), {'__file__': str(source)})
