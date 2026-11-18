#!/usr/bin/env python3
"""Fetch the pinned upstream source of this port into ./upstream (gitignored, never committed) and apply patches/*.patch.

Only the official repository and one fixed tag; the commit is checked after the clone, so a moved tag is noticed.
Nothing from the downloaded tree is executed. Fill in the three values below (the repository URL, a release tag and the
full commit hash of that tag: `git ls-remote <url> <tag>`).
"""
import subprocess
import sys
from pathlib import Path

REPO = ""    # e.g. https://github.com/<owner>/<project>.git
TAG = ""     # e.g. 1.2.3
COMMIT = ""  # the full commit hash the tag points to

here = Path(__file__).resolve().parent
dest = here / "upstream"
if not (REPO and TAG and COMMIT):
    sys.exit("edit fetch.py first: REPO, TAG and COMMIT are empty")
if dest.exists():
    print(f"{dest} exists; nothing to do (delete it to fetch again)")
    sys.exit(0)
subprocess.run(["git", "clone", "--depth", "1", "--branch", TAG, REPO, str(dest)], check=True)
got = subprocess.run(["git", "-C", str(dest), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
if got != COMMIT:
    sys.exit(f"unexpected commit {got} (wanted {COMMIT}); {dest} was left in place, delete it before trying again")
for patch in sorted((here / "patches").glob("*.patch")):
    subprocess.run(["git", "-C", str(dest), "apply", "--ignore-whitespace", str(patch)], check=True)
    print("applied", patch.name)
print("ok:", dest)
