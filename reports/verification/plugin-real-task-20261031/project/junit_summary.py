"""Summarize actual testcase outcomes from local JUnit XML reports."""

import argparse
import json
import sys
import xml.etree.ElementTree as ET


def local_name(tag):
    """Remove an ElementTree namespace prefix."""
    return tag.rsplit('}', 1)[-1]


def count_report(path):
    root = ET.parse(path).getroot()
    if local_name(root.tag) not in ('testsuite', 'testsuites'):
        raise ValueError('unsupported root (expected testsuite or testsuites)')
    counts = dict(tests=0, passed=0, failures=0, errors=0, skipped=0)
    for case in root.iter():
        if local_name(case.tag) != 'testcase':
            continue
        outcomes = {local_name(child.tag) for child in case}
        if 'error' in outcomes:
            outcome = 'errors'
        elif 'failure' in outcomes:
            outcome = 'failures'
        elif 'skipped' in outcomes:
            outcome = 'skipped'
        else:
            outcome = 'passed'
        counts['tests'] += 1
        counts[outcome] += 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reports', nargs='+', metavar='REPORT.xml')
    args = parser.parse_args(argv)
    totals = dict(tests=0, passed=0, failures=0, errors=0, skipped=0)
    for path in args.reports:
        try:
            counts = count_report(path)
        except (OSError, ET.ParseError, ValueError, LookupError) as exc:
            # Keep even multiline OS/parser diagnostics to a single line.
            reason = ' '.join(str(exc).split())
            print(f'junit_summary: {path!r}: {reason}', file=sys.stderr)
            return 2
        for key in totals:
            totals[key] += counts[key]
    print(json.dumps(totals, separators=(',', ':')))
    return 1 if totals['failures'] or totals['errors'] else 0


if __name__ == '__main__':
    sys.exit(main())
