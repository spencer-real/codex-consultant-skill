#!/usr/bin/env python3
"""Gate a Windows Codex child until the parent attaches this process to a job.

The first stdin byte must be G. Bytes after it are the Codex prompt. An EOF,
wrong byte, or failed launch never starts Codex. The job handle stays only in
the parent; Codex inherits job membership through this process.
"""

import os
import subprocess
import sys


def main():
    if os.read(sys.stdin.fileno(), 1) != b"G" or len(sys.argv) < 2:
        return 64
    try:
        process = subprocess.Popen(sys.argv[1:], stdin=sys.stdin.buffer,
                                   stdout=sys.stdout.buffer, stderr=sys.stderr.buffer,
                                   shell=False)
    except OSError:
        return 65
    return process.wait()


if __name__ == "__main__":
    sys.exit(main())
