"""Offline launcher material only: no host allocation, execution or permission edit."""
import re
import shlex


def printable_input_command(serialized):
    # This limited diagnostic accepts the same two fixed synthetic entries only.
    expected = 'diagnostic/a.txt\t' + 'a' * 64 + '\ndiagnostic/b.txt\t' + 'b' * 64
    if serialized != expected:
        raise ValueError('only the fixed synthetic diagnostic input is admitted')
    rows = [row.split('\t') for row in serialized.split('\n')]
    assert all(re.fullmatch('[a-f0-9]{64}', digest) for _, digest in rows)
    # Literal backslashes survive TTY paste; printf format creates TAB/LF later.
    fmt = r'%s\t%s\n%s\t%s'
    return 'rtk proxy printf ' + ' '.join(shlex.quote(x) for x in
        [fmt, rows[0][0], rows[0][1], rows[1][0], rows[1][1]])
