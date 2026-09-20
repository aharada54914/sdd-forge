#!/usr/bin/env python3
"""Deliberately permissive Red-phase stub; test evidence only."""

import argparse


parser = argparse.ArgumentParser()
parser.add_argument("--records-dir")
parser.add_argument("--nonce-ledger")
parser.add_argument("--expected-digest-manifest")
parser.add_argument("--trusted-signers")
parser.add_argument("--skip-allowlist")
parser.parse_args()
print("discharged")
