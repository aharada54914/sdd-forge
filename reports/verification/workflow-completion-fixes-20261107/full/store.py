"""Single-process task storage; os.replace is the transaction commit point.

Share one TaskStore instance between server threads. Each operation revalidates
the file so corruption is surfaced rather than overwritten from a stale cache.
Separate concurrent processes and machine power-loss durability are unsupported.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import threading
from typing import TypedDict
from uuid import UUID, uuid4


class Task(TypedDict):
    id: str
    title: str
    completed: bool


class ValidationError(ValueError):
    """A mutation argument does not satisfy the task contract."""


class TaskNotFoundError(LookupError):
    """A syntactically valid task UUID is absent."""


class StorageError(Exception):
    """Reading, validating, or saving the backing store failed."""


def _title(value: object) -> str:
    if not isinstance(value, str):
        raise ValidationError("タイトルは文字列で指定してください。")
    normalized = value.strip()
    if not 1 <= len(normalized) <= 500:
        raise ValidationError("タイトルは1〜500文字で指定してください。")
    try:
        normalized.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise ValidationError("タイトルに無効な文字が含まれています。") from exc
    return normalized


def _uuid(value: object) -> UUID:
    if not isinstance(value, str):
        raise ValidationError("タスクIDが無効です。")
    try:
        return UUID(value)
    except ValueError as exc:
        raise ValidationError("タスクIDが無効です。") from exc


def _object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate object key")
        result[key] = value
    return result


def _reject_constant(value: str) -> object:
    raise ValueError("non-JSON constant")


def _validate_document(document: object) -> list[Task]:
    if not isinstance(document, dict) or set(document) != {"version", "tasks"}:
        raise ValueError("invalid store envelope")
    if type(document["version"]) is not int or document["version"] != 1:
        raise ValueError("unsupported store version")
    if not isinstance(document["tasks"], list):
        raise ValueError("tasks must be an array")
    tasks: list[Task] = []
    ids: set[UUID] = set()
    for raw in document["tasks"]:
        if not isinstance(raw, dict) or set(raw) != {"id", "title", "completed"}:
            raise ValueError("invalid task fields")
        task_id = _uuid(raw["id"])
        title = _title(raw["title"])
        if title != raw["title"] or type(raw["completed"]) is not bool:
            raise ValueError("invalid persisted task")
        if task_id in ids:
            raise ValueError("duplicate task UUID")
        ids.add(task_id)
        tasks.append(Task(id=raw["id"], title=title, completed=raw["completed"]))
    return tasks


class TaskStore:
    """Load lazily; invalid stores raise StorageError on reads and mutations.

    All successful methods return detached full task lists in creation order.
    ValidationError maps to HTTP 400, TaskNotFoundError to 404, StorageError to
    500. The HTTP adapter must not expose chained filesystem exception details.
    """

    def __init__(self, path: str | os.PathLike[str]) -> None:
        self._path = Path(path).absolute()
        self._lock = threading.Lock()
        self._tasks: list[Task] = []

    def _load(self) -> list[Task]:
        try:
            content = self._path.read_text(encoding="utf-8")
        except FileNotFoundError:
            return []
        except (OSError, UnicodeError) as exc:
            raise StorageError("タスクを読み込めませんでした。") from exc
        try:
            document = json.loads(content, object_pairs_hook=_object,
                                  parse_constant=_reject_constant)
            return _validate_document(document)
        except (ValueError, UnicodeError, RecursionError) as exc:
            raise StorageError("保存データが破損しています。") from exc

    def snapshot(self) -> list[Task]:
        with self._lock:
            self._tasks = self._load()
            return [task.copy() for task in self._tasks]

    def add(self, title: object) -> list[Task]:
        with self._lock:
            normalized = _title(title)
            candidate = self._load()
            task_id = uuid4()
            existing = {_uuid(task["id"]) for task in candidate}
            while task_id in existing:
                task_id = uuid4()
            candidate.append(Task(id=str(task_id), title=normalized, completed=False))
            return self._commit(candidate)

    def set_completed(self, task_id: object, completed: object) -> list[Task]:
        with self._lock:
            identity = _uuid(task_id)
            if not isinstance(completed, bool):
                raise ValidationError("完了状態は真偽値で指定してください。")
            candidate = self._load()
            for task in candidate:
                if _uuid(task["id"]) == identity:
                    task["completed"] = completed
                    return self._commit(candidate)
            raise TaskNotFoundError("タスクが見つかりません。")

    def delete(self, task_id: object) -> list[Task]:
        with self._lock:
            identity = _uuid(task_id)
            candidate = self._load()
            for index, task in enumerate(candidate):
                if _uuid(task["id"]) == identity:
                    del candidate[index]
                    return self._commit(candidate)
            raise TaskNotFoundError("タスクが見つかりません。")

    def _commit(self, candidate: list[Task]) -> list[Task]:
        temporary: Path | None = None
        try:
            serialized = json.dumps({"version": 1, "tasks": candidate},
                                    ensure_ascii=False, allow_nan=False)
            self._path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", dir=self._path.parent,
                prefix=".tasks-", suffix=".tmp", delete=False,
            ) as handle:
                temporary = Path(handle.name)
                handle.write(serialized)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, self._path)
        except (OSError, ValueError, UnicodeError) as exc:
            if temporary is not None:
                try:
                    temporary.unlink(missing_ok=True)
                except OSError as cleanup_error:
                    raise StorageError("保存に失敗し、一時ファイルを削除できませんでした。") from cleanup_error
            raise StorageError("タスクを保存できませんでした。") from exc
        # No fallible filesystem work follows the commit point.
        self._tasks = candidate
        return [task.copy() for task in self._tasks]
