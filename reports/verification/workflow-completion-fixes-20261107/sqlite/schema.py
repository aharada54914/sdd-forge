"""Initial schema v1: publish new files exclusively; validate existing files read-only."""

import os
import sqlite3
import tempfile
from pathlib import Path

_TASKS_SQL = (
    'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0 '
    'CHECK(completed IN (0,1)))'
)


class SchemaError(RuntimeError):
    """Startup cannot safely use the selected database; no recovery was attempted."""


def _validate_existing(path):
    connection = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=2)
    try:
        if connection.execute('PRAGMA user_version').fetchone()[0] != 1:
            raise SchemaError('Unsupported database schema version; expected v1.')
        row = connection.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='tasks'"
        ).fetchone()
        # v1 has one fixed definition. Reject unexpected constraints or omitted
        # AUTOINCREMENT/CHECK clauses, which table_info alone cannot detect.
        if row is None or ''.join(row[0].split()).casefold() != ''.join(_TASKS_SQL.split()).casefold():
            raise SchemaError('Database tasks schema does not match initial schema v1.')
        if connection.execute('PRAGMA quick_check').fetchall() != [('ok',)]:
            raise SchemaError('Database integrity check failed; preserve the file for recovery.')
    finally:
        connection.close()


def _create_initial(path):
    connection = sqlite3.connect(path, timeout=2)
    try:
        connection.execute('BEGIN')
        connection.execute(_TASKS_SQL)
        connection.execute('PRAGMA user_version=1')
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


def initialize_database(db_path):
    """Create a v1 DB or validate it without modifying an existing target.

    Raises SchemaError on storage, version, schema, or publication failure.
    The caller must complete initialization before binding its HTTP socket.
    No upgrades, destructive recovery, or overwrite fallback are performed.
    """
    path = Path(os.path.abspath(db_path))
    temporary = None
    try:
        # lexists includes dangling symlinks: they are existing targets, never
        # invitations to create or overwrite a database at their destination.
        if os.path.lexists(path):
            _validate_existing(path)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, name = tempfile.mkstemp(prefix='.' + path.name + '-', suffix='.tmp', dir=path.parent)
        temporary = Path(name)
        os.close(descriptor)
        _create_initial(temporary)
        _validate_existing(temporary)
        try:
            os.link(temporary, path)
        except FileExistsError:
            # A concurrent creator owns this target. Never replace it.
            _validate_existing(path)
    except (OSError, sqlite3.Error) as error:
        raise SchemaError('Cannot initialize database safely: ' + str(error)) from error
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
