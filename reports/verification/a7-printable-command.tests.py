"""Pure string regression: does not execute any refused shell command or host."""
import hashlib
from pathlib import Path
import runpy
import shlex

HERE = Path(__file__).resolve().parent
build = runpy.run_path(str(HERE / 'a7-printable-command.candidate.py'))['printable_input_command']
canonical = 'diagnostic/a.txt\t' + 'a' * 64 + '\ndiagnostic/b.txt\t' + 'b' * 64
old = 'rtk proxy printf %s ' + shlex.quote(canonical)
observed_paste = lambda text: text.replace('\t', '    ')
assert observed_paste(old) != old
assert hashlib.sha256(canonical.replace('\t', '    ').encode()).digest() != hashlib.sha256(canonical.encode()).digest()
print('PASS original observed TAB substitution changes command and input digest')
fixed = build(canonical)
assert fixed == observed_paste(fixed) and '\t' not in fixed and '\n' not in fixed
rule = 'Bash(' + fixed + ')'
assert rule == 'Bash(' + observed_paste(fixed) + ')'
print('PASS corrected producer and exact rule retain identical printable bytes')
tokens = shlex.split(fixed)
assert tokens[:3] == ['rtk', 'proxy', 'printf'] and len(tokens) == 8
assert tokens[3] == r'%s\t%s\n%s\t%s'
assert tokens[4:] == ['diagnostic/a.txt', 'a' * 64, 'diagnostic/b.txt', 'b' * 64]
# Independent interpretation of this fixed printf format, not shell execution.
output = (tokens[4] + '\t' + tokens[5] + '\n' + tokens[6] + '\t' + tokens[7]).encode()
assert output == canonical.encode() and not output.endswith(b'\n')
assert hashlib.sha256(output).hexdigest() == 'cce7fb17b52a7f54263578114b1bc526f5bc4f53318604c4832299fca3633c05'
print('PASS fixed format preserves canonical digest and no terminal newline')
for bad in (canonical.replace('\t', '    '), canonical + '\n', canonical.replace('a.txt', 'other.txt')):
    try:
        build(bad)
    except ValueError:
        pass
    else:
        raise AssertionError('non-admitted input accepted')
print('PASS changed whitespace, terminal newline and non-admitted path rejected')
print('producer:', fixed)
print('rule:', rule)
print('No host launched; native acceptance and formal authority NOT VERIFIED')
