#!/usr/bin/env python3
"""Select site deployments using a verified successful production baseline."""
import json
import os
from pathlib import Path
import subprocess
import sys


SITES = {
    "homepage": "sites/mads-hartmann.com",
    "blog": "sites/blog.mads-hartmann.com",
    "uses": "sites/uses.mads-hartmann.com",
    "computer": "sites/computer.mads-hartmann.com",
}
SITE_JOB_NAMES = {
    "homepage": "Deploy homepage",
    "blog": "Deploy blog",
    "uses": "Deploy Uses",
    "computer": "Deploy Computer",
}


def github(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def deployment_base(env):
    # A rerun may have partially applied before failing, even if its Git diff is
    # empty. Manual runs intentionally bypass source filtering too.
    if env.get("GITHUB_EVENT_NAME") != "push" or env.get("GITHUB_RUN_ATTEMPT", "1") != "1":
        return None
    repo = env["GITHUB_REPOSITORY"]
    runs = github(
        f"repos/{repo}/actions/workflows/sites.yml/runs?branch=main&event=push&per_page=100"
    )["workflow_runs"]
    previous = [run for run in runs if run["run_number"] < int(env["GITHUB_RUN_NUMBER"])]
    if not previous:
        return None
    run = max(previous, key=lambda item: item["run_number"])
    # Do not trust a net Git diff after a failed/partial deployment: a revert
    # could match the last successful source while production has partial edits.
    if run["status"] != "completed" or run["conclusion"] != "success":
        return None
    jobs = github(f"repos/{repo}/actions/runs/{run['id']}/jobs?per_page=100")["jobs"]
    results = {job["name"]: job["conclusion"] for job in jobs}
    # A green workflow with deployment disabled is not a deployed baseline.
    # Accept the previous display name when inspecting older production runs.
    if results.get("Deploy shared DNS and TLS", results.get("shared / apply")) != "success":
        return None
    if any(
        results.get(SITE_JOB_NAMES[site], results.get(f"{site} / apply")) not in ("success", "skipped")
        and results.get(site) != "skipped"
        for site in SITES
    ):
        return None
    base = run["head_sha"]
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", base, env["GITHUB_SHA"]],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode:
        return None
    return base


def affected_sites(base, head):
    # Treat renames as a removal plus an addition so both owners are selected.
    paths = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", base, head, "--"],
    ).decode().split("\0")
    # Shared build/runtime inputs and deployment tooling affect every site.
    common = ("sites/shared/", "scripts/", ".github/workflows/", ".github/actions/", "terraform/modules/",
              "terraform/stacks/shared/")
    all_changed = any(
        path.startswith(common) or path in ("routing/markdown.js", "routing/redirects.json")
        for path in paths
    )
    return {
        site: all_changed or any(
            path.startswith((source + "/", f"terraform/stacks/{site}/"))
            or path == f"routing/{site}.js"
            for path in paths
        )
        for site, source in SITES.items()
    }


def main():
    os.chdir(Path(__file__).resolve().parent.parent)
    env = os.environ
    selected = {site: True for site in SITES}
    try:
        base = deployment_base(env)
        if base:
            selected = affected_sites(base, env["GITHUB_SHA"])
            print(f"Comparing deployment inputs against {base}.")
        else:
            print("No safe deployment baseline; selecting all sites.")
    except (subprocess.CalledProcessError, OSError, ValueError, KeyError) as error:
        # Missing history or API access must never suppress a deployment.
        print(f"Cannot establish deployment baseline; selecting all sites: {error}", file=sys.stderr)
    if env.get("GITHUB_EVENT_NAME") == "workflow_dispatch":
        stack = env.get("REQUESTED_STACK", "all")
        selected = {site: stack in ("all", site) for site in SITES}
    with open(env["GITHUB_OUTPUT"], "a") as output:
        for site, changed in selected.items():
            print(f"{site}_changed={str(changed).lower()}", file=output)
            print(f"{site}: {'deploy' if changed else 'skip'}")


if __name__ == "__main__":
    main()
