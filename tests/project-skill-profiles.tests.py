#!/usr/bin/env python3
"""Run three synthetic non-verification procedures through the public skill CLI."""
import hashlib
import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'plugins/sdd-bootstrap/scripts/project-skill.py'


@unittest.skipUnless(sys.platform == 'linux', 'owned process-tree backend is Linux-only')
class Profiles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='skill-profile-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.skill = self.root / 'sdd/skills/profile-example'
        self.skill.mkdir(parents=True)
        (self.skill / 'SKILL.md').write_text('---\nname: profile-example\ndescription: Exercise a synthetic procedure.\n---\nUse the declared entry.\n')

    def invoke(self, *args):
        result = subprocess.run([sys.executable, '-B', str(CLI), *args], capture_output=True, text=True, timeout=45)
        try:
            parsed = json.loads(result.stdout)
        except json.JSONDecodeError:
            self.fail('project-skill CLI did not return a JSON result')
        return result.returncode, parsed

    def seal(self, code, requires=()):
        (self.skill / 'run.py').write_text(code)
        options = [item for name in requires for item in ('--requires', name)]
        code, result = self.invoke('seal', '--root', str(self.root), '--name', 'profile-example',
                                   '--runtime', Path(sys.executable).name, '--entry', 'run.py', '--check', 'probe', *options)
        self.assertEqual(code, 0)
        self.assertEqual(result['status'], 'draft')

    def run_skill(self, *inputs):
        options = [item for path in inputs for item in ('--input', path)]
        return self.invoke('run', '--root', str(self.root), '--name', 'profile-example', '--check', 'probe', *options)

    @unittest.skipUnless(shutil.which('git'), 'Git CLI is unavailable')
    def test_diagnosis_runs_real_git_and_retains_failure_boundary(self):
        self.seal('''import subprocess\nfrom pathlib import Path\nmode = Path("scenario.txt").read_text().strip()\nif mode == "failure":\n    subprocess.run(["git", "-C", "missing", "status", "--porcelain"], check=True)\nelse:\n    subprocess.run(["git", "-c", "init.templateDir=", "init", "-q", "sample"], check=True)\n    subprocess.run(["git", "-C", "sample", "status", "--porcelain"], check=True)\n    print("git-diagnosis-ok")\n''', requires=['git'])
        scenario = self.root / 'scenario.txt'
        scenario.write_text('success')
        code, result = self.run_skill('scenario.txt')
        self.assertEqual((code, result['outcome'], result['cleanup']), (0, 'passed', True))
        self.assertIn('git-diagnosis-ok', (self.root / result['stdout']['path']).read_text())
        self.assertFalse((self.root / 'sample').exists())
        scenario.write_text('failure')
        code, result = self.run_skill('scenario.txt')
        self.assertNotEqual(code, 0)
        self.assertEqual((result['outcome'], result['cleanup']), ('failed', True))
        self.assertEqual(scenario.read_text(), 'failure')

    def test_sqlite_migration_rollback_and_invalid_database(self):
        self.seal('''import hashlib, sqlite3\nfrom pathlib import Path\np = Path("input.sqlite")\nbefore = hashlib.sha256(p.read_bytes()).hexdigest()\nwith sqlite3.connect(p) as db:\n    db.execute("BEGIN")\n    db.execute("CREATE TABLE proposed (id INTEGER)")\n    db.execute("INSERT INTO proposed VALUES (1)")\n    db.rollback()\n    assert not db.execute("SELECT name FROM sqlite_master WHERE name='proposed'").fetchall()\nassert hashlib.sha256(p.read_bytes()).hexdigest() == before\nprint("sqlite-rollback-ok")\n''')
        db = self.root / 'input.sqlite'
        with sqlite3.connect(db) as connection:
            connection.execute('CREATE TABLE original (id INTEGER)')
        before = db.read_bytes()
        code, result = self.run_skill('input.sqlite')
        self.assertEqual((code, result['outcome'], result['cleanup']), (0, 'passed', True))
        self.assertEqual(db.read_bytes(), before)
        self.assertIn('sqlite-rollback-ok', (self.root / result['stdout']['path']).read_text())
        db.write_bytes(b'not a database')
        code, result = self.run_skill('input.sqlite')
        self.assertNotEqual(code, 0)
        self.assertEqual((result['outcome'], result['cleanup']), ('failed', True))
        self.assertEqual(db.read_bytes(), b'not a database')

    def test_csv_preparation_records_output_and_rejects_missing_header(self):
        self.seal('''import csv\nfrom pathlib import Path\nwith open("input.csv", newline="") as source:\n    rows = csv.DictReader(source)\n    assert rows.fieldnames == ["name", "value"]\n    values = [(row["name"].strip(), row["value"].strip()) for row in rows]\nwith open("prepared.csv", "w", newline="") as target:\n    writer = csv.writer(target, lineterminator="\\n")\n    writer.writerow(["name", "value"])\n    writer.writerows(values)\nprint("prepared")\n''')
        source = self.root / 'input.csv'
        source.write_text('name,value\n alpha , 7 \n')
        original = source.read_bytes()
        code, result = self.run_skill('input.csv')
        self.assertEqual((code, result['outcome'], result['cleanup']), (0, 'passed', True))
        self.assertEqual(result['observed_outputs']['prepared.csv'], hashlib.sha256(b'name,value\nalpha,7\n').hexdigest())
        self.assertEqual(source.read_bytes(), original)
        self.assertFalse((self.root / 'prepared.csv').exists())
        source.write_text('wrong,value\nalpha,7\n')
        code, result = self.run_skill('input.csv')
        self.assertNotEqual(code, 0)
        self.assertEqual((result['outcome'], result['cleanup']), ('failed', True))
        self.assertEqual(source.read_text(), 'wrong,value\nalpha,7\n')


if __name__ == '__main__':
    unittest.main()
