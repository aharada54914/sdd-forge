"""Repository contract; real SQLite exercises SQL and durable transactions."""
from pathlib import Path
import sqlite3
import tempfile
import time
import unittest
from unittest.mock import patch

import repository
import schema


class ObservedConnection(sqlite3.Connection):
    instances = None
    fail_at = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.events = []
        self.instances.append(self)

    def execute(self, sql, parameters=()):
        self.events.append(('execute', sql, parameters))
        if self.fail_at == 'execute':
            raise sqlite3.OperationalError('injected disk failure')
        return super().execute(sql, parameters)

    def commit(self):
        self.events.append(('commit',))
        if self.fail_at == 'commit':
            raise sqlite3.OperationalError('injected commit failure')
        return super().commit()

    def rollback(self):
        self.events.append(('rollback',))
        return super().rollback()

    def close(self):
        self.events.append(('close',))
        return super().close()


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / 'tasks ?#.db'
        schema.initialize_database(self.db)

    def raw_rows(self):
        conn = sqlite3.connect(self.db)
        try:
            return conn.execute('SELECT id,title,completed FROM tasks ORDER BY id').fetchall()
        finally:
            conn.close()

    def observe_connections(self, failure=None):
        real_connect = sqlite3.connect
        ObservedConnection.instances = []
        ObservedConnection.fail_at = failure
        def connect(*args, **kwargs):
            self.assertEqual(kwargs['timeout'], 2)
            return real_connect(*args, **kwargs, factory=ObservedConnection)
        return patch.object(repository.sqlite3, 'connect', side_effect=connect)

    def test_crud_duplicates_order_and_reopen_durability(self):
        self.assertEqual(repository.list_tasks(self.db), [])
        a = repository.create_task(self.db, '日本語😀')
        b = repository.create_task(self.db, '日本語😀')
        c = repository.create_task(self.db, 'delete me')
        self.assertIsInstance(a, sqlite3.Row)
        self.assertEqual(dict(a), {'id': 1, 'title': '日本語😀', 'completed': 0})
        self.assertEqual([r['id'] for r in repository.list_tasks(self.db)], [1, 2, 3])
        self.assertEqual(repository.set_completed(self.db, a['id'], True)['completed'], 1)
        self.assertEqual(repository.set_completed(self.db, a['id'], False)['completed'], 0)
        repository.set_completed(self.db, b['id'], True)
        self.assertEqual(repository.delete_task(self.db, c['id']), c['id'])
        schema.initialize_database(self.db)
        self.assertEqual(self.raw_rows(), [(1, '日本語😀', 0), (2, '日本語😀', 1)])
        new = repository.create_task(self.db, 'new')
        self.assertGreater(new['id'], c['id'])

    def test_missing_ids_do_not_mutate(self):
        repository.create_task(self.db, 'saved')
        before = self.raw_rows()
        self.assertIsNone(repository.set_completed(self.db, 999, True))
        self.assertIsNone(repository.delete_task(self.db, 999))
        self.assertEqual(self.raw_rows(), before)

    def test_parameterized_titles_are_literal_and_duplicates_allowed(self):
        titles = ["'); DROP TABLE tasks; --", '<script>alert(1)</script>', '😀' * 200]
        for title in titles:
            repository.create_task(self.db, title)
        self.assertEqual([r['title'] for r in repository.list_tasks(self.db)], titles)

    def test_each_operation_owns_and_closes_a_connection(self):
        with self.observe_connections():
            repository.create_task(self.db, 'saved')
            repository.list_tasks(self.db)
            repository.set_completed(self.db, 1, True)
            repository.delete_task(self.db, 1)
        self.assertEqual(len(ObservedConnection.instances), 4)
        for i, conn in enumerate(ObservedConnection.instances):
            self.assertEqual(conn.events[-1], ('close',))
            if i != 1:
                self.assertIn(('commit',), conn.events)
            with self.assertRaises(sqlite3.ProgrammingError):
                sqlite3.Connection.execute(conn, 'SELECT 1')

    def test_failure_rolls_back_closes_and_preserves_saved_rows(self):
        repository.create_task(self.db, 'saved')
        before = self.raw_rows()
        operations = [
            lambda: repository.create_task(self.db, 'not committed'),
            lambda: repository.set_completed(self.db, 1, True),
            lambda: repository.delete_task(self.db, 1),
        ]
        for failure in ('execute', 'commit'):
            for operation in operations:
                with self.subTest(failure=failure, operation=operation):
                    with self.observe_connections(failure):
                        with self.assertRaises(sqlite3.OperationalError):
                            operation()
                    conn = ObservedConnection.instances[0]
                    self.assertIn(('rollback',), conn.events)
                    self.assertEqual(conn.events[-1], ('close',))
                    self.assertEqual(self.raw_rows(), before)

    def test_read_failure_closes_connection(self):
        with self.observe_connections('execute'):
            with self.assertRaises(sqlite3.OperationalError):
                repository.list_tasks(self.db)
        self.assertEqual(ObservedConnection.instances[0].events[-1], ('close',))

    def test_real_lock_is_bounded_and_does_not_mutate(self):
        repository.create_task(self.db, 'saved')
        conn = sqlite3.connect(self.db)
        try:
            conn.execute('BEGIN IMMEDIATE')
            start = time.monotonic()
            with self.assertRaises(sqlite3.OperationalError):
                repository.create_task(self.db, 'blocked')
            elapsed = time.monotonic() - start
            self.assertGreaterEqual(elapsed, 1.5)
            self.assertLess(elapsed, 4.0)
        finally:
            conn.rollback()
            conn.close()
        self.assertEqual(self.raw_rows(), [(1, 'saved', 0)])
        self.assertEqual(repository.create_task(self.db, 'after lock')['id'], 2)

    def test_missing_database_is_not_recreated(self):
        missing = self.db.parent / 'missing.db'
        with self.assertRaises(sqlite3.OperationalError):
            repository.list_tasks(missing)
        self.assertFalse(missing.exists())


if __name__ == '__main__':
    unittest.main()
