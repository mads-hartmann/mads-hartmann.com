"""Materialize Bazel artifacts in the layout consumed by Terraform and previews."""

from pathlib import Path
import shutil
import sys

selected, output = sys.argv[1:]
output = Path(output)
sites = ["homepage", "blog", "uses", "computer"] if selected == "all" else [selected]
for site in sites:
    destination = Path(".build") / site
    if destination.exists():
        for path in [destination, *destination.rglob("*")]:
            if path.is_dir():
                path.chmod(0o755)
        shutil.rmtree(destination)
    shutil.copytree(output / (site + ".content"), destination, copy_function=shutil.copyfile)
    for path in [destination, *destination.rglob("*")]:
        path.chmod(0o755 if path.is_dir() else 0o644)
    for folder, suffix in [("routing", ".js"), ("manifests", ".json")]:
        target = Path(".build") / folder / (site + suffix)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(output / folder / (site + suffix), target)
