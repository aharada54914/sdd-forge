#!/usr/bin/env python3
"""Propose model registry/policy updates from the vendors' official model pages (ADR-0055).

Fetched page text is untrusted. Only model-ID tokens that match a vendor's
fixed allowlist pattern are read from it; nothing else from a page reaches a
contract, a document or a pull-request body. A token is added only when the
family rules (contracts/model-families.v1.json) classify it: it gets the
family's tier, the efforts of the newest registered model of the same family
(or of the same vendor and tier), lifecycle `current` and no adoption
evidence, so it is listed and checkable but never selected automatically.
Unclassified tokens, a jump of two or more major versions, and current models
a successfully fetched page no longer shows, are only reported; no lifecycle
is changed automatically.

  update-model-registry.py --fetch --write --report body.md   # CI: fetch, update files, print summary JSON
  update-model-registry.py --source anthropic=FILE --source openai=FILE --source google=FILE [--write]
"""
import argparse
import datetime
import html
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ('contracts/agent-model-capabilities.v2.json', 'plugins/sdd-implementation/contracts/agent-model-capabilities.v2.json')
POLICY = 'contracts/model-policy.v1.json'
FAMILIES = 'contracts/model-families.v1.json'
VENDORS = {
    # Version components are one or two digits, so dated snapshots (-YYYYMMDD) are never routing IDs.
    'anthropic': {'url': 'https://docs.anthropic.com/en/docs/about-claude/models',
                  'token': r'claude-[a-z]+-[0-9]{1,2}(?:-[0-9]{1,2})?', 'hosts': ('claude-code',),
                  'canonical': lambda native: 'anthropic/' + native[len('claude-'):]},
    'openai': {'url': 'https://learn.chatgpt.com/docs/models',
               'token': r'gpt-[0-9]{1,2}(?:\.[0-9]{1,2})?-[a-z]+', 'hosts': ('codex-cli',),
               'canonical': lambda native: native},
    'google': {'url': 'https://aistudio.google.com/docs/models',
               'token': r'gemini-[0-9]{1,2}(?:\.[0-9]{1,2})?-[a-z]+(?:-[a-z]+)?', 'hosts': ('gemini-cli', 'antigravity-cli'),
               'canonical': lambda native: 'google/' + native},
}
# Google lists non-chat and preview variants that are not routing candidates.
IGNORED = re.compile(r'-(preview|tts|live|image|embedding|translate|robotics|computer|audio)(-|$)')
TIERS = ('lightweight', 'standard', 'strong')


def page_text(raw):
    """Visible text of an HTML page; script and style bodies are dropped, never interpreted."""
    raw = re.sub(r'(?is)<(script|style)\b.*?</\1\s*>', ' ', raw)
    return html.unescape(re.sub(r'(?s)<[^>]+>', ' ', raw))


def id_segments(raw):
    """Only code-style notation names a model: HTML <code>, Markdown `code`, and Markdoc "Model code **id**".

    Headings, anchors and URL slugs are skipped: a slug drops version dots (gemini-25-...)."""
    segments = [re.sub(r'(?s)<[^>]+>', ' ', c) for c in re.findall(r'(?is)<code\b[^>]*>(.*?)</code\s*>', raw)]
    text = page_text(raw)
    segments += re.findall(r'`([^`\n]{1,200})`', text)
    segments += re.findall(r'Model code\*?\s*\*\*([^*\n]{1,100})\*\*', text)
    return html.unescape('\n'.join(segments))


def tokens(vendor, raw):
    pattern = re.compile(r'(?<![A-Za-z0-9.-])(' + VENDORS[vendor]['token'] + r')(?![A-Za-z0-9-]|\.[0-9])')
    return sorted({m.group(1) for m in pattern.finditer(id_segments(raw)) if not IGNORED.search(m.group(1))})


def version(native):
    """Numeric version components of a native ID, e.g. gpt-6.2-sol -> (6, 2); () when absent."""
    numbers = tuple(int(x) for x in re.findall(r'[0-9]+', native))
    return numbers + (0,) * (4 - len(numbers)) if numbers else ()


def classify(native, rules):
    tiers = {(tier, family) for pattern, tier, vendor, family in rules if pattern.fullmatch(native)}
    return next(iter(tiers)) if len({t for t, _ in tiers}) == 1 and len(tiers) == 1 else None


def plan(sources, root=ROOT, today=None):
    today = today or datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT00:00:00Z')
    registry = json.loads((root / REGISTRY[0]).read_text(encoding='utf-8'))
    policy = json.loads((root / POLICY).read_text(encoding='utf-8'))
    family_data = json.loads((root / FAMILIES).read_text(encoding='utf-8'))
    rules = [(re.compile(f['pattern']), f['tier'], f['vendor'], f['family']) for f in family_data['families']]
    registered = {m['name']: m for m in registry['models']}
    known = {(host, native) for m in policy['models'] for host, native in m['hosts'].items()}
    summary = {'schema': 'model-registry-update/v1', 'date': today[:10], 'added': [], 'unclassified': [],
               'older_or_listed': [], 'suspicious': [], 'not_seen': [], 'unavailable': []}
    for vendor, spec in VENDORS.items():
        raw = sources.get(vendor)
        if raw is None:
            summary['unavailable'].append(vendor)
            continue
        found = tokens(vendor, raw)
        host = spec['hosts'][0]
        for native in found:
            if (host, native) in known:
                continue
            verdict = classify(native, rules)
            if verdict is None:
                summary['unclassified'].append(native)
                continue
            tier, family = verdict
            # Only a newer version of an already registered family is added: a
            # new family, or an older version a page still lists, is reported.
            family_members = [m for m in policy['models'] if host in m['hosts']
                              and classify(m['hosts'][host], rules) == (tier, family) and version(m['hosts'][host])]
            siblings = sorted((m for m in family_members if m['lifecycle'] == 'current'),
                              key=lambda m: version(m['hosts'][host]))
            newest = max((version(m['hosts'][host]) for m in family_members), default=None)
            if not siblings or newest is None or version(native) <= newest:
                summary['unclassified' if not family_members else 'older_or_listed'].append(native)
                continue
            if version(native)[0] > newest[0] + 1:  # a jump of two or more major versions is not trusted
                summary['suspicious'].append(native)
                continue
            template = registered[siblings[-1]['id']]
            name = spec['canonical'](native)
            if name in registered:
                continue
            registry['models'].append({'name': name, 'canonical_tier': tier,
                                       'supported_efforts': list(template['supported_efforts']),
                                       'default_effort': template['default_effort'],
                                       'effort_control': dict(template['effort_control'])})
            registered[name] = registry['models'][-1]
            policy['models'].append({'id': name, 'lifecycle': 'current', 'source_url': spec['url'],
                                     'source_date': today, 'successor_of': [s['id'] for s in siblings[-1:]],
                                     'hosts': {h: native for h in spec['hosts']}, 'adoption': []})
            for value in policy['roles'].values():
                prefs = value['preferences']
                same = [i for i, p in enumerate(prefs) if p in registered and registered[p]['canonical_tier'] == tier]
                if not same:
                    continue
                vendor_same = [i for i in same if any(h in VENDORS[vendor]['hosts'] for h in
                                                      next(m for m in policy['models'] if m['id'] == prefs[i])['hosts'])]
                prefs.insert((vendor_same or same)[0], name)
            known.add((host, native))
            summary['added'].append({'id': name, 'native_id': native, 'tier': tier, 'family': family, 'vendor': vendor})
        seen = set(found)
        for model in policy['models']:
            native = model['hosts'].get(host)
            if model['lifecycle'] == 'current' and native and native not in seen:
                summary['not_seen'].append(native)
    if summary['added']:
        policy['source_date'] = today
    return registry, policy, summary


def report(summary):
    """Markdown for the job summary and the pull-request body.

    Every model name in it passed a vendor's fixed token pattern; no other page text is used."""
    def names(key):
        values = summary[key]
        return ', '.join('`%s`' % v for v in values) if values else 'なし'
    lines = ['## モデル登録の更新案（%s）' % summary['date'], '']
    if summary['added']:
        lines += ['| 追加する ID | ホストでの ID | ティア | 系列 |', '|---|---|---|---|']
        lines += ['| `%s` | `%s` | %s | %s |' % (a['id'], a['native_id'], a['tier'], a['family']) for a in summary['added']]
        lines += ['', '追加したモデルは `lifecycle: current`、`adoption: []` です。採用の根拠を記録するまで自動では選ばれません。']
    else:
        lines.append('追加するモデルはありません。')
    lines += ['', '### 確認だけが必要なもの（自動では変更しない）', '',
              '- 系列の規則に合わない ID: ' + names('unclassified'),
              '- 公式ページに見当たらない現行モデル: ' + names('not_seen'),
              '- 2世代以上の飛び越しとして保留した ID: ' + names('suspicious'),
              '- 取得できなかったベンダー: ' + names('unavailable'), '']
    return '\n'.join(lines)


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'sdd-forge-model-registry-update'})
    with urllib.request.urlopen(request, timeout=20) as response:  # noqa: S310 - fixed HTTPS vendor URLs
        return response.read(4 * 1024 * 1024).decode('utf-8', 'replace')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--fetch', action='store_true', help='fetch the official pages')
    parser.add_argument('--source', action='append', default=[], metavar='VENDOR=FILE')
    parser.add_argument('--write', action='store_true', help='write contracts and regenerate the tables')
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--today')
    parser.add_argument('--report', type=Path, metavar='FILE', help='also write the summary as Markdown')
    args = parser.parse_args(argv)
    sources = {}
    for item in args.source:
        vendor, _, path = item.partition('=')
        if vendor not in VENDORS or not path:
            parser.error('--source must be anthropic|openai|google=FILE')
        sources[vendor] = Path(path).read_text(encoding='utf-8')
    if args.fetch:
        for vendor, spec in VENDORS.items():
            if vendor in sources:
                continue
            try:
                sources[vendor] = fetch(spec['url'])
            except OSError:
                pass  # reported as unavailable; nothing changes for that vendor
    registry, policy, summary = plan(sources, args.root, args.today)
    if args.write and summary['added']:
        text = json.dumps(registry, indent=2) + '\n'
        for rel in REGISTRY:
            (args.root / rel).write_text(text, encoding='utf-8')
        (args.root / POLICY).write_text(json.dumps(policy, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        subprocess.run([sys.executable, str(args.root / 'scripts/render-model-routing-docs.py'), '--root', str(args.root)],
                       check=True)
    if args.report:
        args.report.write_text(report(summary), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
