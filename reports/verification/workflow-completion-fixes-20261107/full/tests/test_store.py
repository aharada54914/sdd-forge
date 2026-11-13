"""T-001 tests use real temporary JSON and filesystem boundary faults."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from unittest.mock import Mock, patch
from uuid import UUID, uuid4

from store import StorageError, TaskNotFoundError, TaskStore, ValidationError


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "data" / "tasks.json"
        self.store = TaskStore(self.path)

    def seed(self):
        return self.store.add("最初のタスク")

    def assert_preserved(self, before, snapshot):
        # Observe published memory before snapshot() can reload it from disk.
        self.assertEqual(self.store._tasks, snapshot)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.store.snapshot(), snapshot)
        self.assertEqual(set(self.path.parent.iterdir()), {self.path})

    def test_missing_store_is_empty_until_first_save(self):
        self.assertEqual(self.store.snapshot(), [])
        self.assertFalse(self.path.exists())
        result = self.seed()
        self.assertEqual(json.loads(self.path.read_text()), {"version": 1, "tasks": result})

    def test_add_trims_unicode_and_appends_unique_ids(self):
        first = self.store.add(" \t\u3000買い物\n")[0]
        result = self.store.add("買い物")
        self.assertEqual(result[0], first)
        self.assertEqual(first["title"], "買い物")
        self.assertIs(first["completed"], False)
        self.assertEqual(set(first), {"id", "title", "completed"})
        self.assertNotEqual(first["id"], result[1]["id"])
        for task in result:
            self.assertEqual(str(UUID(task["id"])), task["id"])

    def test_unicode_code_point_limit_and_literal_html(self):
        title = "😀" * 500
        self.assertEqual(self.store.add(" " + title + " ")[-1]["title"], title)
        literal = '<script>alert("x")</script>'
        self.assertEqual(self.store.add(literal)[-1]["title"], literal)

    def test_invalid_titles_preserve_disk(self):
        expected = self.seed()
        before = self.path.read_bytes()
        for title in ("", " ", "\u3000", "\n\t", "a" * 501, None, True, 3, [], {}, "\ud800"):
            with self.subTest(title=repr(title)), self.assertRaises(ValidationError):
                self.store.add(title)
            self.assert_preserved(before, expected)

    def test_completion_is_explicit_bidirectional_and_preserves_order(self):
        first = self.seed()[0]
        original = self.store.add("次のタスク")
        for completed in (True, True, False):
            result = self.store.set_completed(first["id"], completed)
            self.assertIs(result[0]["completed"], completed)
            self.assertEqual([task["id"] for task in result], [task["id"] for task in original])
            self.assertEqual(TaskStore(self.path).snapshot(), result)

    def test_invalid_boolean_preserves_disk(self):
        expected = self.seed()
        before = self.path.read_bytes()
        for value in (0, 1, None, "true", [], {}):
            with self.subTest(value=value), self.assertRaises(ValidationError):
                self.store.set_completed(expected[0]["id"], value)
            self.assert_preserved(before, expected)

    def test_invalid_and_unknown_ids_do_not_write(self):
        expected = self.seed()
        before = self.path.read_bytes()
        operations = (self.store.delete, lambda value: self.store.set_completed(value, True))
        for task_id in ("", "bad", None, 1, True, [], {}):
            for operation in operations:
                with self.subTest(task_id=task_id), self.assertRaises(ValidationError):
                    operation(task_id)
                self.assert_preserved(before, expected)
        for operation in operations:
            with self.assertRaises(TaskNotFoundError):
                operation(str(uuid4()))
            self.assert_preserved(before, expected)

    def test_delete_persists_remaining_order_and_empty_list(self):
        first = self.seed()[0]
        second = self.store.add("次")[1]
        third = self.store.add("最後")[2]
        self.assertEqual(self.store.delete(second["id"]), [first, third])
        self.assertEqual(TaskStore(self.path).snapshot(), [first, third])
        self.store.delete(first["id"])
        self.assertEqual(self.store.delete(third["id"]), [])
        self.assertEqual(json.loads(self.path.read_text()), {"version": 1, "tasks": []})

    def test_returned_snapshots_and_mutation_results_are_detached(self):
        result = self.seed()
        original_id = result[0]["id"]
        result[0]["title"] = "changed outside"
        result.clear()
        snapshot = self.store.snapshot()
        snapshot[0]["completed"] = True
        snapshot.append({"id": "bad", "title": "bad", "completed": True})
        expected = [{"id": original_id, "title": "最初のタスク", "completed": False}]
        self.assertEqual(self.store.snapshot(), expected)
        self.assertEqual(json.loads(self.path.read_text())["tasks"], expected)

    def test_restart_in_separate_process_recovers_all_fields(self):
        first = self.seed()[0]
        deleted = self.store.add("削除対象")[1]
        self.store.set_completed(first["id"], True)
        self.store.delete(deleted["id"])
        expected = self.store.add("保存済み😀")
        result = subprocess.run(
            [sys.executable, "-B", "-c",
             "import json,sys; from store import TaskStore; "
             "print(json.dumps(TaskStore(sys.argv[1]).snapshot(),ensure_ascii=False))",
             str(self.path)],
            cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout), expected)

    def test_corrupt_envelopes_preserve_exact_bytes_on_reads_and_mutations(self):
        task = self.seed()[0]
        valid = {"version": 1, "tasks": [task]}
        invalid = [b"{", b"\xff", b'{"version":1,"version":1,"tasks":[]}',
                   b'{"version":1,"tasks":[],"tasks":[]}', b'{"version":NaN,"tasks":[]}',
                   b"[]", b"null", b'{"version":true,"tasks":[]}',
                   b'{"version":1.0,"tasks":[]}', b'{"version":2,"tasks":[]}',
                   b'{"tasks":[]}', b'{"version":1}', b'{"version":1,"tasks":{}}',
                   b'{"version":1,"tasks":[],"extra":0}']
        invalid.append(json.dumps({**valid, "tasks": [task, task]}).encode())
        duplicate = {**task, "id": task["id"].upper()}
        invalid.append(json.dumps({**valid, "tasks": [task, duplicate]}).encode())
        invalid.append(json.dumps(valid).replace(
            '"completed": false', '"completed": false, "completed": true').encode())
        for data in invalid:
            self.path.write_bytes(data)
            operations = (self.store.snapshot, lambda: self.store.add("追加"),
                          lambda: self.store.set_completed(task["id"], True),
                          lambda: self.store.delete(task["id"]),
                          lambda: TaskStore(self.path).snapshot())
            for operation in operations:
                with self.subTest(data=data), self.assertRaises(StorageError):
                    operation()
                self.assertEqual(self.store._tasks, [task])
                self.assertEqual(self.path.read_bytes(), data)

    def test_invalid_persisted_tasks_are_never_normalized_or_overwritten(self):
        task = self.seed()[0]
        invalid_tasks = [None, [], {}, {**task, "extra": 1}, {**task, "id": "bad"},
                         {**task, "id": 1}, {**task, "title": " padded "},
                         {**task, "title": ""}, {**task, "title": "x" * 501},
                         {**task, "title": 3}, {**task, "title": "\ud800"},
                         {**task, "completed": 1}, {**task, "completed": "false"}]
        for invalid in invalid_tasks:
            data = json.dumps({"version": 1, "tasks": [invalid]}).encode()
            self.path.write_bytes(data)
            with self.subTest(task=invalid), self.assertRaises(StorageError):
                self.store.add("must not overwrite")
            self.assertEqual(self.store._tasks, [task])
            self.assertEqual(self.path.read_bytes(), data)
            with self.assertRaises(StorageError):
                self.store.snapshot()
            self.assertEqual(self.store._tasks, [task])

    def test_fsync_failure_preserves_old_state_and_cleans_only_own_temp(self):
        expected = self.seed()
        before = self.path.read_bytes()
        unrelated = self.path.parent / "other-operation.tmp"
        unrelated.write_bytes(b"untouched")
        with patch("store.os.fsync", side_effect=OSError("injected fsync failure")):
            with self.assertRaises(StorageError):
                self.store.set_completed(expected[0]["id"], True)
        self.assertEqual(self.store._tasks, expected)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.store.snapshot(), expected)
        self.assertEqual(unrelated.read_bytes(), b"untouched")
        self.assertEqual(set(self.path.parent.iterdir()), {self.path, unrelated})

    def test_replace_failure_preserves_add_completion_and_delete(self):
        expected = self.seed()
        before = self.path.read_bytes()
        operations = (lambda: self.store.add("new"),
                      lambda: self.store.set_completed(expected[0]["id"], True),
                      lambda: self.store.delete(expected[0]["id"]))
        for operation in operations:
            with patch("store.os.replace", side_effect=OSError("injected replace failure")):
                with self.assertRaises(StorageError):
                    operation()
            self.assert_preserved(before, expected)

    def test_first_save_failure_leaves_no_store_and_can_recover(self):
        with patch("store.os.replace", side_effect=OSError("replace")):
            with self.assertRaises(StorageError):
                self.seed()
        self.assertEqual(self.store._tasks, [])
        self.assertFalse(self.path.exists())
        self.assertEqual(self.store.snapshot(), [])
        self.assertEqual(list(self.path.parent.iterdir()), [])
        self.assertEqual(len(self.seed()), 1)

    def test_temporary_creation_failure_preserves_existing_state(self):
        expected = self.seed()
        before = self.path.read_bytes()
        with patch("store.tempfile.NamedTemporaryFile", side_effect=OSError("create")):
            with self.assertRaises(StorageError):
                self.store.add("new")
        self.assert_preserved(before, expected)

    def test_write_and_flush_failures_preserve_existing_state(self):
        expected = self.seed()
        before = self.path.read_bytes()
        original = tempfile.NamedTemporaryFile
        for method in ("write", "flush"):
            def faulty_temp(*args, **kwargs):
                handle = original(*args, **kwargs)
                setattr(handle, method, Mock(side_effect=OSError(method)))
                return handle
            with patch("store.tempfile.NamedTemporaryFile", side_effect=faulty_temp):
                with self.subTest(method=method), self.assertRaises(StorageError):
                    self.store.add("new")
            self.assert_preserved(before, expected)

    def test_close_failure_preserves_disk_and_published_state(self):
        expected = self.seed()
        before = self.path.read_bytes()
        original = tempfile.NamedTemporaryFile
        close_attempts = []

        @contextmanager
        def faulty_temp(*args, **kwargs):
            # Use a real file, including its actual write/flush/fsync and close.
            # Inject the close error at context exit after releasing the real
            # descriptor, so the failure test cannot leak descriptors.
            with original(*args, **kwargs) as handle:
                yield handle
            self.assertTrue(handle.file.closed)
            close_attempts.append(Path(handle.name))
            raise OSError("injected temporary-file close failure")

        with patch("store.tempfile.NamedTemporaryFile", side_effect=faulty_temp):
            with self.assertRaises(StorageError) as raised:
                self.store.set_completed(expected[0]["id"], True)
        self.assertIsInstance(raised.exception.__cause__, OSError)
        self.assertEqual(len(close_attempts), 1)
        self.assert_preserved(before, expected)
        self.assertFalse(close_attempts[0].exists())

    def test_cleanup_unlink_failure_preserves_disk_and_published_state(self):
        expected = self.seed()
        before = self.path.read_bytes()
        unrelated = self.path.parent / "unrelated.tmp"
        unrelated.write_bytes(b"must remain untouched")
        with patch("store.os.replace", side_effect=OSError("replace failure")):
            with patch("store.Path.unlink", autospec=True,
                       side_effect=PermissionError("cleanup denied")) as unlink:
                with self.assertRaises(StorageError) as raised:
                    self.store.set_completed(expected[0]["id"], True)
        self.assertEqual(self.store._tasks, expected)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertIsInstance(raised.exception.__cause__, PermissionError)
        unlink.assert_called_once()
        temporary = unlink.call_args.args[0]
        self.assertEqual(temporary.parent, self.path.parent)
        self.assertNotIn(temporary, (self.path, unrelated))
        self.assertEqual(unlink.call_args.kwargs, {"missing_ok": True})
        self.assertEqual(set(self.path.parent.iterdir()), {self.path, unrelated, temporary})
        self.assertEqual(unrelated.read_bytes(), b"must remain untouched")
        self.assertIs(json.loads(temporary.read_text())["tasks"][0]["completed"], True)
        self.assertEqual(self.store.snapshot(), expected)

    def test_read_failure_never_overwrites_store(self):
        expected = self.seed()
        before = self.path.read_bytes()
        with patch("store.Path.read_text", side_effect=PermissionError("read")):
            for operation in (self.store.snapshot, lambda: self.store.add("new")):
                with self.assertRaises(StorageError):
                    operation()
                self.assertEqual(self.store._tasks, expected)
        self.assert_preserved(before, expected)

    def test_parent_directory_failure_does_not_publish_candidate(self):
        with patch("store.Path.mkdir", side_effect=PermissionError("mkdir")):
            with self.assertRaises(StorageError):
                self.seed()
        self.assertEqual(self.store._tasks, [])
        self.assertEqual(self.store.snapshot(), [])
        self.assertFalse(self.path.exists())

    def test_commit_uses_synced_same_directory_file_then_replace(self):
        expected = self.seed()
        before = self.path.read_bytes()
        events = []
        original_fsync, original_replace = os.fsync, os.replace

        def fsync(fd):
            events.append("fsync")
            original_fsync(fd)

        def replace(source, destination):
            self.assertEqual(self.store._tasks, expected)
            self.assertEqual(Path(source).parent, self.path.parent)
            self.assertEqual(Path(destination), self.path)
            self.assertEqual(self.path.read_bytes(), before)
            candidate = json.loads(Path(source).read_text())
            self.assertIs(candidate["tasks"][0]["completed"], True)
            self.assertEqual(events, ["fsync"])
            events.append("replace")
            original_replace(source, destination)

        with patch("store.os.fsync", side_effect=fsync), patch("store.os.replace", side_effect=replace):
            result = self.store.set_completed(expected[0]["id"], True)
        self.assertEqual(events, ["fsync", "replace"])
        self.assertEqual(json.loads(self.path.read_text())["tasks"], result)

    def test_concurrent_adds_and_completions_have_no_lost_updates(self):
        workers = 12
        barrier = threading.Barrier(workers)

        def add(index):
            barrier.wait(timeout=10)
            return len(self.store.add(f"task-{index}"))

        with ThreadPoolExecutor(max_workers=workers) as executor:
            lengths = list(executor.map(add, range(workers)))
        self.assertEqual(sorted(lengths), list(range(1, workers + 1)))
        tasks = self.store.snapshot()
        self.assertEqual({task["title"] for task in tasks}, {f"task-{i}" for i in range(workers)})
        self.assertEqual(len({task["id"] for task in tasks}), workers)
        with ThreadPoolExecutor(max_workers=workers) as executor:
            list(executor.map(lambda task: self.store.set_completed(task["id"], True), tasks))
        self.assertTrue(all(task["completed"] for task in self.store.snapshot()))
        self.assertEqual(TaskStore(self.path).snapshot(), self.store.snapshot())


if __name__ == "__main__":
    unittest.main()
