"""Check that a development server actually serves the expected site."""
import argparse
import json
import os
from pathlib import Path
import sys
import time
import urllib.request
import urllib.parse

ROOT = Path(__file__).resolve().parents[2]
PORTS = {"homepage": ("HOMEPAGE_PORT", "8080"), "blog": ("BLOG_PORT", "4000"), "uses": ("USES_PORT", "8081")}


def check(site):
    variable, default = PORTS[site]
    base = f"http://127.0.0.1:{os.environ.get(variable, default)}"
    paths = ["/"] if site != "blog" else ["/", "/feed.xml"]
    if site == "blog":
        routes = json.loads((ROOT / "routing/redirects.json").read_text())["homepage"]
        paths.append(urllib.parse.urlsplit(next(iter(routes.values()))).path)
    for path in paths:
        with urllib.request.urlopen(base + path, timeout=3) as response:
            body = response.read()
            assert response.status == 200, f"{site}{path}: HTTP {response.status}"
        if site != "blog":
            assert body == (ROOT / ".build" / site / "index.html").read_bytes(), f"{site}: response differs from generated page"
        else:
            marker = b"<feed" if path == "/feed.xml" else b"Mads Hartmann"
            assert marker in body, f"blog{path}: missing expected content"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", choices=[*PORTS, "all"])
    parser.add_argument("--wait", type=float, default=0)
    args = parser.parse_args()
    sites = PORTS if args.site == "all" else [args.site]
    deadline = time.monotonic() + args.wait
    while True:
        try:
            for site in sites:
                check(site)
            print(f"Verified {', '.join(sites)} development server(s)")
            return 0
        except (OSError, AssertionError) as error:
            if time.monotonic() >= deadline:
                print(str(error), file=sys.stderr)
                return 1
            time.sleep(0.5)


if __name__ == "__main__":
    sys.exit(main())
