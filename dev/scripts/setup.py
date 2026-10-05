"""Frozen dependency setup shared by root and project devenv tasks."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def run(args, cwd):
    return subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=True).stdout.strip()


def settings(project):
    directory = ROOT / "sites" / f"{project}.mads-hartmann.com"
    if project == "blog":
        manifests = [directory / "Gemfile", directory / "Gemfile.lock"]
        identity = [
            run(["ruby", "--version"], directory),
            run(["bundle", "--version"], directory),
            os.environ["BUNDLE_PATH"],
            os.environ.get("DEV_PROTOBUF_CFLAGS", ""),
        ]
        check = ["bundle", "exec", "ruby", "-e",
                 "require 'jekyll'; require 'eventmachine'; require 'ffi'; require 'google/protobuf'"]
        install = ["bundle", "install"]
    else:
        manifests = [directory / "package.json", directory / "package-lock.json"]
        identity = [run(["node", "--version"], directory), run(["npm", "--version"], directory)]
        check = ["node", "--input-type=module", "-e",
                 "import {marked} from 'marked'; if (!marked('# ready').includes('<h1>ready</h1>')) process.exit(1)"]
        install = ["npm", "ci", "--ignore-scripts"]
    digest = hashlib.sha256(json.dumps(identity).encode())
    for manifest in manifests:
        digest.update(manifest.read_bytes())
    return directory, digest.hexdigest(), check, install


def installed(directory, check):
    result = subprocess.run(check, cwd=directory, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def prepare_protobuf(directory):
    # This release builds both extconf.rb and a Rakefile. Bundler build arguments
    # reach both, but Rake rejects --with-cflags. Pass mkmf's supported environment
    # option only while installing this exact gem, then let Bundler verify the lock.
    if "    google-protobuf (3.25.2)\n" not in (directory / "Gemfile.lock").read_text():
        return
    check = ["ruby", "-rgoogle/protobuf", "-e",
             "exit(Gem.loaded_specs['google-protobuf'].version.to_s == '3.25.2' ? 0 : 1)"]
    if installed(directory, check):
        return
    environment = os.environ.copy()
    environment["CONFIGURE_ARGS"] = " ".join([
        environment.get("CONFIGURE_ARGS", ""), environment["DEV_PROTOBUF_CFLAGS"],
    ])
    subprocess.run([
        "gem", "install", "google-protobuf", "--version", "3.25.2", "--platform", "ruby", "--no-document",
    ], cwd=directory, env=environment, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", choices=["blog", "uses"])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    directory, fingerprint, check, install = settings(args.project)
    state = Path(os.environ["DEV_STATE"]) / "setup"
    state.mkdir(parents=True, exist_ok=True)
    stamp = state / f"{args.project}.sha256"
    # Root/leaf activation can overlap; never install into the same tree concurrently.
    with (state / f"{args.project}.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = (stamp.exists() and stamp.read_text().strip() == fingerprint
                   and installed(directory, check))
        if args.check:
            return 0 if current else 1
        if current:
            print(f"{args.project}: dependencies already installed")
            return 0
        if args.project == "blog":
            prepare_protobuf(directory)
        subprocess.run(install, cwd=directory, check=True)
        if not installed(directory, check):
            raise RuntimeError(f"{args.project}: installed dependencies failed the runtime check")
        temporary = stamp.with_suffix(".tmp")
        temporary.write_text(fingerprint + "\n")
        temporary.replace(stamp)
        return 0


if __name__ == "__main__":
    sys.exit(main())
