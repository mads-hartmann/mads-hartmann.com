"""Run existing generators against only their declared inputs."""

import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    site, destination, runtime, *sources = sys.argv[1:]
    destination = Path(destination).resolve()
    tools = json.loads(Path(runtime).read_text())
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        for source in sources:
            target = work / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            # Jekyll can read static-file mtimes. Checkout time is not an input.
            os.utime(target, (0, 0))
        directory = "mads-hartmann.com" if site == "homepage" else site + ".mads-hartmann.com"
        (work / "sites" / directory / "node_modules").symlink_to(tools["siteModules"])
        (work / "scripts/node_modules").symlink_to(tools["buildModules"])
        if site in ["homepage", "uses", "computer"]:
            command = [tools["node"], f"sites/{directory}/build.mjs", str(destination)]
        elif site == "blog":
            source = work / "sites/blog.mads-hartmann.com/src"
            # Use publication dates, not wall-clock time or Git history, for
            # Jekyll's site.time (including the Atom feed's updated timestamp).
            dates = []
            for post in (source / "_posts").glob("*"):
                match = re.search(r"^date:\s+(.+)$", post.read_text(), re.MULTILINE)
                if match:
                    date = datetime.datetime.fromisoformat(match[1].strip().strip("\"'"))
                    if date.tzinfo is None:
                        date = date.replace(tzinfo=datetime.timezone.utc)
                    dates.append(date)
            # Jekyll treats a document date equal to site.time as an unset
            # default and replaces it with the filename's midnight timestamp.
            timestamp = (max(dates) + datetime.timedelta(seconds=1)).isoformat()
            config = work / "production.yml"
            config.write_text(f'time: "{timestamp}"\ntimezone: UTC\n')
            command = [tools["jekyll"], "build", "--source", str(source), "--destination", str(destination),
                       "--config", f"{source / '_config.yml'},{config}",
                       "--disable-disk-cache", "--strict_front_matter"]
        else:
            raise ValueError(f"Unknown site: {site}")
        subprocess.run(command, cwd=work, check=True)
        subprocess.run([tools["node"], "scripts/fingerprint-assets.mjs", str(destination)], cwd=work, check=True)


if __name__ == "__main__":
    main()
