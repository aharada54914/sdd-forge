"""Static exact-rule candidate for A7; never launches a reviewer or Bash."""

import hashlib
import json
import shlex

fixture = 'reports/verification/a7-exact-hash-permission-probe-20261006.txt'
outside = 'reports/verification/a7-custom-host-permission-probe-20261006.md'
rows = [('diagnostic/a.txt', 'a' * 64), ('diagnostic/b.txt', 'b' * 64)]
canonical = '\n'.join(path + '\t' + digest for path, digest in rows)
input_hash = hashlib.sha256(canonical.encode()).hexdigest()
receipt = '2|impl|impl-reviewer-a|diagnostic-run|diagnostic-session|-|allowed-inputs-v1|' + input_hash

file_hash = 'rtk proxy shasum -a 256 ' + fixture
input_producer = "rtk proxy printf '%s\\t%s\\n%s\\t%s' " + ' '.join(
    shlex.quote(value) for row in rows for value in row
)
receipt_producer = 'rtk proxy printf %s ' + shlex.quote(receipt)
hash_stdin = 'rtk proxy shasum -a 256'
directory_check = 'rtk proxy test -d domain'
input_pipeline = input_producer + ' | ' + hash_stdin
receipt_pipeline = receipt_producer + ' | ' + hash_stdin
negative = 'rtk proxy shasum -a 256 ' + outside

whole_pipeline_rules = {'Bash(' + command + ')' for command in (
    file_hash, input_pipeline, receipt_pipeline, directory_check
)}
component_rules = {'Bash(' + command + ')' for command in (
    file_hash, input_producer, receipt_producer, hash_stdin, directory_check
)}
required_components = {input_producer, receipt_producer, hash_stdin}

# Claude's compound-command matcher needs each subcommand independently allowed.
assert all('Bash(' + command + ')' not in whole_pipeline_rules
           for command in required_components)
assert all('Bash(' + command + ')' in component_rules
           for command in required_components)
assert 'Bash(' + negative + ')' not in component_rules
assert all('*' not in rule for rule in component_rules)
assert all(' | ' not in rule for rule in component_rules)
assert input_pipeline == input_producer + ' | ' + hash_stdin
assert receipt_pipeline == receipt_producer + ' | ' + hash_stdin

print(json.dumps({
    'candidate_only': True,
    'native_permission_verified': False,
    'missing_under_whole_pipeline_only': sorted(required_components),
    'candidate_allowed_tools': sorted(component_rules),
    'out_of_scope_hash_allowed': False,
}, ensure_ascii=False, indent=2))
