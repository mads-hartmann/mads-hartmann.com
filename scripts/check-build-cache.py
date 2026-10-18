"""Exercise invalidation in a temporary copy; never edit the working checkout.

Run inside devenv shell. This intentionally runs outside `bazel test` because
it tests Bazel itself, including repository-rule evaluation and tool changes.
"""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
files = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
).decode().split("\0")

with tempfile.TemporaryDirectory(prefix="sites-cache-check-") as directory:
    directory = Path(directory)
    workspace = directory / "repo"
    workspace.mkdir()
    for name in files:
        source = root / name
        if name and source.is_file():
            destination = workspace / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    bazel = ["bazel", "--batch", "--output_base=" + str(directory / "output")]

    def build():
        result = subprocess.run(
            bazel + ["build", "//:sites", "--subcommands", "--noshow_progress",
                     "--disk_cache=" + str(directory / "cache")],
            cwd=workspace, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if result.returncode:
            raise RuntimeError(result.stdout)
        actions = {line.split("//:", 1)[1].split()[0]
                   for line in result.stdout.splitlines() if line.startswith("SUBCOMMAND: # //:")}
        manifests = {site: json.loads((workspace / "bazel-bin/manifests" / (site + ".json")).read_text())
                     for site in ["homepage", "blog", "uses", "computer"]}
        return actions, manifests

    def check(name, path, transform, expected_builds, changed_content):
        source = workspace / path
        original = source.read_text()
        try:
            source.write_text(transform(original))
            actions, manifests = build()
            builds = actions & {"homepage", "blog", "uses", "computer"}
            assert builds == expected_builds, (name, actions)
            for site in ["homepage", "blog", "uses", "computer"]:
                changed = manifests[site]["content_digest"] != baseline[site]["content_digest"]
                assert changed == (site in changed_content), (name, site, manifests[site])
            if name == "infrastructure":
                assert manifests["uses"]["bundle_digest"] != baseline["uses"]["bundle_digest"]
            print(f"PASS {name}: rebuilt {sorted(builds)}; content changed {sorted(changed_content)}", flush=True)
        finally:
            source.write_text(original)
            build()

    _, baseline = build()
    actions, repeated = build()
    assert not actions and baseline == repeated, actions
    print("PASS unchanged build: all actions cached", flush=True)
    check("documentation", "README.md", lambda s: s + "\nCache probe.\n", set(), set())
    check("blog only", "sites/blog.mads-hartmann.com/src/_posts/2026-01-27-using-ai-to-do-your-best-work.md",
          lambda s: s + "\nCache probe.\n", {"blog"}, {"blog"})
    check("Computer content", "sites/computer.mads-hartmann.com/index.md",
          lambda s: s + "\nCache probe.\n", {"computer"}, {"computer"})
    check("same rendered output", "sites/uses.mads-hartmann.com/build.mjs",
          lambda s: s + "\n// Cache probe.\n", {"uses"}, set())
    check("Uses content", "sites/uses.mads-hartmann.com/index.md",
          lambda s: s + "\nCache probe.\n", {"uses"}, {"uses"})
    check("shared footer", "sites/shared/footer/footer.html",
          lambda s: s + "\n<!-- Cache probe. -->\n",
          {"homepage", "blog", "uses", "computer"}, {"homepage", "blog", "uses", "computer"})
    check("infrastructure", "terraform/stacks/uses/main.tf",
          lambda s: s + "\n# Cache probe.\n", set(), set())
    check("Nix tool", "dev/bazel/tools.nix",
          lambda s: s.replace('uses.mads-hartmann.com) {};', 'uses.mads-hartmann.com) { cacheProbe = "changed"; };'),
          {"uses"}, set())
