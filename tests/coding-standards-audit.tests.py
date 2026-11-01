#!/usr/bin/env python3
"""Run the full native audit through the existing verification catalog."""
import sys
from coding_standards import main

if __name__ == '__main__':
    sys.argv[1:] = ['scan', '--mode', 'all']
    raise SystemExit(main())
