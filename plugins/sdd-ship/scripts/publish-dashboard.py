#!/usr/bin/env python3
"""Supervise a bounded collector and publish to one private Site; credentials never enter logs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import random
import signal
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

MAX_BYTES = 2 * 1024 * 1024


def now():
    return datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def version(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()[:12]


def classify(error):
    if isinstance(error, urllib.error.HTTPError):
        if error.code in (401, 403):
            return 'auth-failed'
        if error.code in (400, 413):
            return 'data-rejected'
        if error.code == 409:
            return 'conflict'
        return 'http-failed'
    return 'transport-failed'


def backoff(failures, jitter=random.random):
    return min(60, 5 * 2 ** min(max(failures - 1, 0), 4)) * (0.8 + 0.2 * jitter())


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Collector:
    """One current observation, no stale FIFO backlog during network outages."""
    def __init__(self, entry, root):
        self.version = version(entry)
        self.started = time.monotonic()
        self.items = queue.Queue(maxsize=1)
        self.process = subprocess.Popen(['node', entry, '--root', root, '--dashboard-monitor-stream'],
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.thread = threading.Thread(target=self.read, daemon=True)
        self.thread.start()

    def read(self):
        while True:
            line = self.process.stdout.readline(MAX_BYTES + 2)
            if not line:
                return
            if len(line) > MAX_BYTES:
                self.process.terminate()
                return
            try:
                self.items.get_nowait()
            except queue.Empty:
                pass
            self.items.put_nowait(line)

    def sample(self, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                return json.loads(self.items.get(timeout=min(0.5, max(0.01, deadline-time.monotonic()))))
            except queue.Empty:
                if self.process.poll() is not None:
                    raise RuntimeError('collector-exited')
        raise TimeoutError('collector-timeout')

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.thread.join(timeout=1)
        self.process.stdout.close()


def post(opener, origin, path, payload, credentials):
    body = json.dumps(payload, ensure_ascii=True).encode('utf-8')
    if len(body) > MAX_BYTES:
        raise ValueError('payload-too-large')
    req = urllib.request.Request(origin + path, data=body, method='PUT', headers={
        'Content-Type': 'application/json',
        'OAI-Sites-Authorization': 'Bearer ' + credentials['serviceToken'],
        'X-SDD-Publisher': credentials['publisherToken'],
    })
    with opener.open(req, timeout=25) as response:
        result = json.loads(response.read(65536))
    if result.get('ok') is not True:
        raise ValueError('invalid-acknowledgement')
    return result


def supervise(args, credentials):
    opener = urllib.request.build_opener(NoRedirect)
    health = {'schema': 'sdd-monitor/v1', 'observedAt': now(), 'state': 'starting',
              'publisherVersion': version(__file__), 'collectorVersion': version(args.entry),
              'lastPublishAt': None, 'lastSourceAt': None, 'consecutiveFailures': 0,
              'collectorRestarts': 0, 'collectionMs': 0, 'lastError': None}
    collector = None
    failures = 0
    try:
        while True:
            outcome = 'running'
            try:
                if collector is None:
                    collector = Collector(args.entry, args.root)
                    health['collectorVersion'] = collector.version
                snapshot = collector.sample()
                # Source clock and duration are emitted by the collector; do not substitute HTTP success.
                if not isinstance(snapshot, dict) or snapshot.get('schema') != 'sdd-dashboard/v1':
                    raise ValueError('invalid-collector-output')
                health['collectionMs'] = snapshot.pop('_collectionMs', 0)
                if not isinstance(health['collectionMs'], (int, float)) or not 0 <= health['collectionMs'] <= 3600000:
                    raise ValueError('invalid-duration')
            except (OSError, RuntimeError, TimeoutError, ValueError):
                outcome = 'collection-failed'
                if collector:
                    collector.close()
                    collector = None
                health['collectorRestarts'] += 1
            if outcome == 'running':
                try:
                    post(opener, args.url, '/api/snapshot', snapshot, credentials)
                    health['lastPublishAt'] = now()
                    health['lastSourceAt'] = snapshot.get('lastSuccessAt')
                    if snapshot.get('error'):
                        outcome = 'source-failed'
                except urllib.error.URLError as error:
                    outcome = classify(error)
                except (ValueError, OSError):
                    outcome = 'data-rejected'
            failures = 0 if outcome == 'running' else failures + 1
            health.update(observedAt=now(), state=outcome, lastError=None if outcome == 'running' else outcome,
                          consecutiveFailures=failures)
            try:
                post(opener, args.url, '/api/health', health, credentials)
            except (urllib.error.URLError, ValueError, OSError):
                # A failed health upload must not appear as a fresh heartbeat at the destination.
                if outcome == 'running':
                    print(json.dumps({'event': 'health-publish-failed'}), flush=True)
            if not args.quiet or outcome != 'running':
                print(json.dumps({'event': 'publisher-cycle', **health}), flush=True)
            if outcome in ('auth-failed', 'data-rejected'):
                return 78  # Requires operator correction; service must not restart-loop.
            if args.once:
                return 0 if outcome == 'running' else 1
            if outcome != 'running':
                time.sleep(backoff(failures))
    finally:
        if collector:
            collector.close()


def credentials_from_stdin():
    saved = None
    if sys.stdin.isatty() and os.name == 'posix':
        import termios
        saved = termios.tcgetattr(sys.stdin)
        hidden = list(saved)
        hidden[3] &= ~termios.ECHO
        termios.tcsetattr(sys.stdin, termios.TCSANOW, hidden)
    print('Ready for publisher credentials JSON on stdin (input hidden).', flush=True)
    try:
        return json.loads(sys.stdin.readline(16384))
    finally:
        if saved:
            termios.tcsetattr(sys.stdin, termios.TCSANOW, saved)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--entry', required=True)
    parser.add_argument('--root', required=True)
    parser.add_argument('--url', required=True)
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--systemd-credentials', action='store_true', help='Read systemd runtime credential named sites-publisher')
    args = parser.parse_args()
    url = urllib.parse.urlparse(args.url)
    if url.scheme != 'https' or not url.netloc or url.username or url.password or url.query or url.fragment or url.path not in ('', '/'):
        parser.error('--url must be an HTTPS Site origin')
    args.url = args.url.rstrip('/')
    if args.systemd_credentials:
        directory = os.environ.get('CREDENTIALS_DIRECTORY')
        if not directory:
            raise ValueError('missing-systemd-credentials')
        credentials = json.loads((Path(directory) / 'sites-publisher').read_text())
    else:
        credentials = credentials_from_stdin()
    if not isinstance(credentials, dict) or not all(isinstance(credentials.get(k), str) and credentials[k] and '\n' not in credentials[k] and '\r' not in credentials[k] for k in ('serviceToken', 'publisherToken')):
        raise ValueError('invalid-credentials')
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    return supervise(args, credentials)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (ValueError, OSError):
        print(json.dumps({'event': 'publisher-setup-failed'}), file=sys.stderr)
        sys.exit(78)
