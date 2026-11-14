"""Committed task CRUD for already validated input and initialized databases.

Each public operation owns one SQLite connection and returns detached Row data
with integer completion values. HTTP validation/DTO serialization belong to
the caller. SQLite failures propagate so the caller cannot report success.
"""

import sqlite3
from contextlib import contextmanager
from pathlib import Path


@contextmanager
def _connection(db_path, *, write=False):
    # mode=rw prevents a removed/mistyped path from silently becoming an empty DB.
    connection = sqlite3.connect(
        Path(db_path).absolute().as_uri() + '?mode=rw', uri=True, timeout=2
    )
    try:
        connection.row_factory = sqlite3.Row
        if write:
            connection.execute('BEGIN')
        yield connection
        if write:
            connection.commit()
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


def list_tasks(db_path):
    """Return committed tasks in ascending ID order."""
    with _connection(db_path) as connection:
        return connection.execute('SELECT id,title,completed FROM tasks ORDER BY id').fetchall()


def create_task(db_path, title):
    """Insert a validated title, returning its unchecked row after commit."""
    with _connection(db_path, write=True) as connection:
        cursor = connection.execute('INSERT INTO tasks(title) VALUES (?)', (title,))
        return connection.execute(
            'SELECT id,title,completed FROM tasks WHERE id=?', (cursor.lastrowid,)
        ).fetchone()


def set_completed(db_path, task_id, completed):
    """Commit the specified boolean state; return the saved Row or None."""
    with _connection(db_path, write=True) as connection:
        cursor = connection.execute(
            'UPDATE tasks SET completed=? WHERE id=?', (int(completed), task_id)
        )
        if cursor.rowcount == 0:
            return None
        return connection.execute(
            'SELECT id,title,completed FROM tasks WHERE id=?', (task_id,)
        ).fetchone()


def delete_task(db_path, task_id):
    """Commit deletion, returning the deleted ID or None for an unknown ID."""
    with _connection(db_path, write=True) as connection:
        cursor = connection.execute('DELETE FROM tasks WHERE id=?', (task_id,))
        return task_id if cursor.rowcount else None
