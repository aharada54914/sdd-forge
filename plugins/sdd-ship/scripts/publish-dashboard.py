#!/usr/bin/env python3
"""Stream guarded observations to one private Site. Secrets arrive on stdin, never in argv/files."""
import argparse
import json
import os
import signal
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--entry', required=True)
    parser.add_argument('--root', required=True)
    parser.add_argument('--url', required=True)
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--quiet', action='store_true', help='Suppress successful heartbeat logs')
    args = parser.parse_args()
    url = urllib.parse.urlparse(args.url)
    if url.scheme != 'https' or not url.netloc or url.username or url.password or url.query or url.fragment or url.path not in ('', '/'):
        parser.error('--url must be an HTTPS Site origin')
    # Disable terminal echo before announcing readiness, including on interactive starts.
    if sys.stdin.isatty() and os.name == 'posix':
        import termios
        flags = termios.tcgetattr(sys.stdin)
        flags[3] &= ~termios.ECHO
        termios.tcsetattr(sys.stdin, termios.TCSANOW, flags)
    print('Ready for publisher credentials JSON on stdin (input hidden).', flush=True)
    credentials = json.loads(sys.stdin.readline())
    if not all(isinstance(credentials.get(k), str) and credentials[k] for k in ('serviceToken', 'publisherToken')):
        raise ValueError('Both credentials are required')
    # Do not follow redirects with authentication headers.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = urllib.request.build_opener(NoRedirect)
    command = ['node', args.entry, '--root', args.root, '--dashboard-snapshot' if args.once else '--dashboard-stream']
    child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        for line in child.stdout:
            body = line.encode('utf-8')
            request = urllib.request.Request(args.url.rstrip('/') + '/api/snapshot', data=body, method='PUT', headers={
                'Content-Type': 'application/json',
                'OAI-Sites-Authorization': 'Bearer ' + credentials['serviceToken'],
                'X-SDD-Publisher': credentials['publisherToken'],
            })
            try:
                with opener.open(request, timeout=25) as response:
                    result = json.load(response)
                if result.get('ok') is not True:
                    raise ValueError('Publisher did not acknowledge update')
                if not args.quiet:
                    print(json.dumps({'published': True, 'checkedAt': result.get('checkedAt'), 'revision': result.get('revision')}), flush=True)
            except (urllib.error.URLError, ValueError):
                print(json.dumps({'published': False, 'error': 'Update failed; retained data will become stale'}), flush=True)
                if args.once:
                    return 1
        return child.wait()
    finally:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
