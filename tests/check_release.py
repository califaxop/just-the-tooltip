#!/usr/bin/env python3
"""Just the Tooltip! release check: python3 tests/check_release.py

Before a release, checks that:
- the version is the same in the toc, the CHANGELOG and the README's "Recent changes";
- every file the toc loads exists, and every Lua file is loaded;
- the companion's toc version and the data format match what the code reads;
- the source data passes tools/sources/validate.py;
- the release workflow leaves the developer files out of the zip and validates the data before
  uploading;
- the offline tests pass.

Prints each check and exits 1 if any fails.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
fails = []


def check(ok, what):
    print(("ok    " if ok else "FAIL  ") + what)
    if not ok:
        fails.append(what)


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


toc = read("JustTheTooltip.toc")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
changelog = re.search(r"^## (\d+\.\d+\.\d+)", read("CHANGELOG.md"), re.M)
readme = re.search(r"^- \*\*(\d+\.\d+\.\d+)[^*]*\*\*", read("README.md"), re.M)
check(changelog and changelog.group(1) == version, "CHANGELOG starts with " + version)
check(readme and readme.group(1) == version, "README's Recent changes start with " + version)

loaded = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
check(all(os.path.isfile(os.path.join(ROOT, f)) for f in loaded), "every file the toc loads exists")
on_disk = sorted(f for f in os.listdir(ROOT) if f.endswith(".lua"))
check(sorted(loaded) == on_disk, "every Lua file is in the toc")

sources = read("Sources.lua")
fmt = re.search(r"S\.FORMAT = (\d+)", sources).group(1)
data_fmt = re.search(r"^version = (\d+),", read("JustTheTooltip_Sources", "Data.lua"), re.M)
check(data_fmt and data_fmt.group(1) == fmt, "the source data's format (%s) is the one the code reads" % fmt)
comp = re.search(r"^## Version:\s*(\S+)", read("JustTheTooltip_Sources", "JustTheTooltip_Sources.toc"), re.M)
check(comp is not None, "the companion has a version (%s)" % (comp.group(1) if comp else "?"))

sys.path.insert(0, os.path.join(ROOT, "tools", "sources"))
import validate  # noqa: E402
problems = validate.validate()
check(not problems, "the source data passes validate.py" + ("" if not problems else ": " + problems[0]))

wf = read(".github", "workflows", "release.yml")
for name in ("README.md", "CHANGELOG.md", "DEVELOPMENT.md", "API_COMPATIBILITY.md", "INTEGRATIONS.md", "SOURCE_DATA.md", "/tests", "/tools"):
    check("--exclude='%s'" % name in wf, "the release zip leaves out " + name)
check("validate.py" in wf, "the release workflow validates the source data before uploading")

r = subprocess.run([sys.executable, os.path.join(HERE, "run_tests.py")], capture_output=True, text=True)
last = (r.stdout.strip().splitlines() or ["?"])[-1]
check(r.returncode == 0, "offline tests: " + last)

print("\n" + ("release check passed" if not fails else "%d check(s) failed" % len(fails)))
sys.exit(1 if fails else 0)
