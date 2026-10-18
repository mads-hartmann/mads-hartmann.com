"""Stage Bazel runfiles for the existing checks without mutating build outputs."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

mode, runtime, *inputs = sys.argv[1:]
runtime = str(Path(runtime).resolve())
with tempfile.TemporaryDirectory(dir=os.environ.get("TEST_TMPDIR")) as directory:
    work = Path(directory)
    for name in inputs:
        source = Path(name)
        if source.name == "tool.json":
            # The blog's image checks use its own pinned Sharp dependency.
            target = work / "sites/blog.mads-hartmann.com/node_modules"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(json.loads(source.read_text())["siteModules"])
        elif source.is_dir() and source.name.endswith(".content"):
            target = work / ".build" / source.name.removesuffix(".content")
            shutil.copytree(source, target)
        else:
            if name.startswith("routing/") and source.suffix == ".js":
                target = work / ".build" / name
            else:
                target = work / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    if runtime.endswith(".json"):
        tools = json.loads(Path(runtime).read_text())
        os.environ["PATH"] = tools["path"]
        (work / "scripts/node_modules").symlink_to(tools["buildModules"])
        runtime = tools["node"]
    if mode == "deployments":
        command = [tools["python"], "-m", "unittest", "discover", "-s", "scripts/tests", "-p", "test_*.py"]
    elif mode == "workflows":
        command = [runtime, "-shellcheck=", *[str(p) for p in sorted((work / ".github/workflows").glob("*.yml"))]]
    elif mode == "manifest":
        command = [runtime, "scripts/test-site-manifest.py"]
    else:
        command = [runtime, "scripts/check-sites.mjs", mode]
    subprocess.run(command, cwd=work, check=True)
