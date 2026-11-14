"""Storage startup contract, using real files except injected failures."""
import os
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

import schema


EXPECTED_SQL = (
    'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0 '
    'CHECK(completed IN (0,1)))'
)


class FailingConnection(sqlite3.Connection):
    fail_at = None
    events = None

    def execute(self, sql, parameters=()):
        self.events.append(sql)
        if self.fail_at == 'create' and sql.lstrip().upper().startswith('CREATE'):
            raise sqlite3.OperationalError('injected create failure')
        return super().execute(sql, parameters)

    def commit(self):
        self.events.append('commit')
        if self.fail_at == 'commit':
            raise sqlite3.OperationalError('injected commit failure')
        return super().commit()

    def rollback(self):
        self.events.append('rollback')
        return super().rollback()

    def close(self):
        self.events.append('close')
        return super().close()


class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.db = self.root / 'new folder' / 'tasks ?#.sqlite3'

    def make_existing(self, sql=EXPECTED_SQL, version=1):
        self.db.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db)
        try:
            conn.execute(sql)
            conn.execute(f'PRAGMA user_version={version}')
            conn.commit()
        finally:
            conn.close()

    def test_initial_schema_constraints_version_and_no_temp_files(self):
        schema.initialize_database(self.db)
        conn = sqlite3.connect(self.db)
        try:
            self.assertEqual(conn.execute('PRAGMA user_version').fetchone(), (1,))
            self.assertEqual(conn.execute('PRAGMA journal_mode').fetchone(), ('delete',))
            conn.execute('INSERT INTO tasks(title) VALUES (?)', ('日本語😀',))
            self.assertEqual(conn.execute('SELECT id,title,completed FROM tasks').fetchall(),
                             [(1, '日本語😀', 0)])
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute('INSERT INTO tasks(title,completed) VALUES (?,?)', ('bad', 2))
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute('INSERT INTO tasks(title) VALUES (NULL)')
            conn.commit()
        finally:
            conn.close()
        self.assertEqual(list(self.db.parent.iterdir()), [self.db])

    def test_restart_preserves_exact_bytes_rows_and_inode(self):
        self.make_existing()
        conn = sqlite3.connect(self.db)
        conn.execute('INSERT INTO tasks(title,completed) VALUES (?,?)', ('saved', 1))
        conn.commit()
        conn.close()
        before, inode = self.db.read_bytes(), self.db.stat().st_ino
        schema.initialize_database(self.db)
        self.assertEqual(self.db.read_bytes(), before)
        self.assertEqual(self.db.stat().st_ino, inode)

    def test_existing_validation_opens_read_only_uri(self):
        self.make_existing()
        real_connect = sqlite3.connect
        calls = []
        def connect(*args, **kwargs):
            calls.append((args, kwargs))
            return real_connect(*args, **kwargs)
        with patch.object(schema.sqlite3, 'connect', side_effect=connect):
            schema.initialize_database(self.db)
        self.assertEqual(len(calls), 1)
        self.assertIn('mode=ro', calls[0][0][0])
        self.assertTrue(calls[0][1]['uri'])

    def test_mismatch_and_corruption_fail_without_changing_file(self):
        cases = [
            ('wrong-version', EXPECTED_SQL, 2),
            ('missing-check', EXPECTED_SQL.replace(' CHECK(completed IN (0,1))', ''), 1),
            ('wrong-columns', 'CREATE TABLE tasks(id INTEGER PRIMARY KEY, title TEXT)', 1),
            ('missing-autoincrement', EXPECTED_SQL.replace(' AUTOINCREMENT', ''), 1),
        ]
        for name, sql, version in cases:
            with self.subTest(name=name):
                self.db = self.root / (name + '.sqlite3')
                self.make_existing(sql, version)
                before = self.db.read_bytes()
                with self.assertRaises(schema.SchemaError):
                    schema.initialize_database(self.db)
                self.assertEqual(self.db.read_bytes(), before)
        for name, content in [('corrupt', b'not a database'), ('empty', b'')]:
            with self.subTest(name=name):
                self.db = self.root / name
                self.db.write_bytes(content)
                with self.assertRaises(schema.SchemaError):
                    schema.initialize_database(self.db)
                self.assertEqual(self.db.read_bytes(), content)

    def test_create_and_commit_failures_rollback_close_and_leave_target_absent(self):
        real_connect = sqlite3.connect
        for failure in ('create', 'commit'):
            with self.subTest(failure=failure):
                events = []
                FailingConnection.events = events
                FailingConnection.fail_at = failure
                def connect(*args, **kwargs):
                    return real_connect(*args, **kwargs, factory=FailingConnection)
                with patch.object(schema.sqlite3, 'connect', side_effect=connect):
                    with self.assertRaises(schema.SchemaError):
                        schema.initialize_database(self.db)
                self.assertFalse(self.db.exists())
                self.assertEqual(list(self.db.parent.iterdir()), [])
                self.assertIn('BEGIN', events)
                self.assertIn('rollback', events)
                self.assertEqual(events[-1], 'close')

    def test_publication_failure_does_not_fall_back_to_overwrite(self):
        with patch.object(schema.os, 'link', side_effect=OSError('unsupported link')):
            with self.assertRaises(schema.SchemaError):
                schema.initialize_database(self.db)
        self.assertFalse(self.db.exists())
        self.assertEqual(list(self.db.parent.iterdir()), [])

    def test_concurrent_target_is_validated_and_never_overwritten(self):
        for valid in (True, False):
            with self.subTest(valid=valid):
                self.db = self.root / ('valid.db' if valid else 'invalid.db')
                captured = []
                def race(source, target):
                    if valid:
                        self.make_existing()
                    else:
                        self.db.write_bytes(b'concurrent contents')
                    captured.append(self.db.read_bytes())
                    raise FileExistsError('concurrent target')
                with patch.object(schema.os, 'link', side_effect=race):
                    if valid:
                        schema.initialize_database(self.db)
                    else:
                        with self.assertRaises(schema.SchemaError):
                            schema.initialize_database(self.db)
                self.assertEqual(self.db.read_bytes(), captured[0])
                self.assertFalse(any(p.name.endswith('.tmp') for p in self.root.iterdir()))


if __name__ == '__main__':
    unittest.main()
