#!/usr/bin/env python3
"""Prove a bounded quoted Python evidence writer is data-only; never execute it."""
import ast
import json
import os
from pathlib import Path
import re
import stat
import sys


class Rejected(ValueError):
    pass


def classify(command, root):
    if any(key.startswith('BASH_FUNC_') or key in ('BASH_ENV', 'ENV') for key in os.environ):
        return False
    match = re.fullmatch(r"python3? -I - <<'([A-Za-z_][A-Za-z0-9_]*)'\n(.*)\n\1\s*", command, re.S)
    if not match or match[1] in match[2].splitlines():
        return False
    root = Path(root)
    if not root.is_absolute() or root.resolve() != root:
        return False
    # The *executed writer*, not just this classifier, must use isolated Python.
    # Otherwise any transitive stdlib import can execute a project-local module.
    tree = ast.parse(match[2])
    names = {}
    writes = 0

    def path_value(node):
        value = expression(node)
        if not isinstance(value, tuple) or len(value) != 2 or value[0] != 'path':
            raise Rejected()
        return value[1]

    def safe_destination(value):
        # Only ordinary diagnostic artifacts, never any workflow authority file.
        path = Path(value)
        if path.is_absolute() or '..' in path.parts or not path.parts:
            raise Rejected()
        if path.parts[0] not in ('evidence', 'reports') or path.suffix not in ('.json', '.md', '.txt', '.log'):
            raise Rejected()
        if path.name in ('tasks.md', 'design.md', 'context-map.md') or any(
            part.startswith('.') or part in ('review-context', 'spec-review', 'impl-review', 'task-review', 'quality-gate')
            for part in path.parts
        ):
            raise Rejected()
        current = Path(root)
        for part in path.parts:
            current /= part
            if current.is_symlink():
                raise Rejected()
        if current.exists():
            info = current.stat()
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                raise Rejected()
        return True

    def expression(node):
        nonlocal writes
        if isinstance(node, ast.Constant) and isinstance(node.value, (str, int, float, bool, type(None))):
            return node.value
        if isinstance(node, ast.Name) and node.id in names:
            return names[node.id]
        if isinstance(node, (ast.List, ast.Tuple, ast.Set)):
            return [expression(value) for value in node.elts]
        if isinstance(node, ast.Dict):
            if any(key is None for key in node.keys):
                raise Rejected()
            for key, value in zip(node.keys, node.values):
                expression(key)
                expression(value)
            return {}
        if isinstance(node, ast.Compare):
            expression(node.left)
            for value in node.comparators:
                expression(value)
            return True
        if isinstance(node, ast.BoolOp):
            for value in node.values:
                expression(value)
            return True
        if isinstance(node, ast.Call):
            if any(keyword.arg is None for keyword in node.keywords):
                raise Rejected()
            for keyword in node.keywords:
                expression(keyword.value)
            if isinstance(node.func, ast.Name):
                if node.func.id == 'Path' and names.get('Path') == ('import', 'pathlib.Path') and len(node.args) == 1 and not node.keywords:
                    value = expression(node.args[0])
                    if not isinstance(value, str):
                        raise Rejected()
                    return ('path', value)
                if node.func.id == 'print':
                    if any(keyword.arg not in ('sep', 'end', 'flush') for keyword in node.keywords):
                        raise Rejected()
                    for value in node.args:
                        expression(value)
                    return None
            if isinstance(node.func, ast.Attribute):
                owner = node.func.value
                if isinstance(owner, ast.Name) and owner.id == 'json' and names.get('json') == ('import', 'json') and node.func.attr == 'dumps':
                    if len(node.args) != 1 or any(keyword.arg not in ('ensure_ascii', 'indent', 'sort_keys') for keyword in node.keywords):
                        raise Rejected()
                    expression(node.args[0])
                    return ''
                if node.func.attr in ('read_text', 'write_text'):
                    value = path_value(owner)
                    if any(keyword.arg not in ('encoding', 'errors') for keyword in node.keywords):
                        raise Rejected()
                    if node.func.attr == 'read_text' and not node.args:
                        return ''
                    if node.func.attr == 'write_text' and len(node.args) == 1:
                        safe_destination(value)
                        expression(node.args[0])
                        writes += 1
                        return 0
                if node.func.attr == 'replace' and len(node.args) == 2 and not node.keywords and isinstance(expression(owner), str):
                    if not all(isinstance(expression(value), str) for value in node.args):
                        raise Rejected()
                    return ''
        raise Rejected()

    for statement in tree.body:
        if isinstance(statement, ast.Import) and len(statement.names) == 1 and statement.names[0].name == 'json' and statement.names[0].asname is None and 'json' not in names:
            names['json'] = ('import', 'json')
        elif isinstance(statement, ast.ImportFrom) and statement.module == 'pathlib' and statement.level == 0 and len(statement.names) == 1 and statement.names[0].name == 'Path' and statement.names[0].asname is None and 'Path' not in names:
            names['Path'] = ('import', 'pathlib.Path')
        elif isinstance(statement, ast.Assign) and len(statement.targets) == 1 and isinstance(statement.targets[0], ast.Name) and statement.targets[0].id not in ('json', 'Path', 'print'):
            names[statement.targets[0].id] = expression(statement.value)
        elif isinstance(statement, ast.Expr):
            expression(statement.value)
        elif isinstance(statement, ast.Assert) and statement.msg is None:
            expression(statement.test)
        else:
            raise Rejected()
    return writes > 0


if __name__ == '__main__':
    try:
        value = json.load(sys.stdin)
        result = classify(value['command'], value['root'])
    except (ValueError, TypeError, KeyError, OSError, SyntaxError, RecursionError):
        result = False
    print(json.dumps(result))
