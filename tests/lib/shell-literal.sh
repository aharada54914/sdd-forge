# Serialize one data value as a POSIX shell literal for generated test fixtures.
# The authoring tests use Bash; the generated program may use /bin/sh.
shell_literal() {
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

# Replace fixture path bytes literally; paths are never regular expressions.
replace_file_literal() {
    python3 - "$@" <<'PYTHON'
import os
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_bytes(path.read_bytes().replace(os.fsencode(sys.argv[2]), os.fsencode(sys.argv[3])))
PYTHON
}
