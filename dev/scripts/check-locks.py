"""Ensure every project resolves the same shared inputs."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
environments = [root, *(root / "sites").glob("*/devenv.yaml")]
environments = [entry.parent if entry.is_file() else entry for entry in environments]
environments.append(root / "terraform")
reference = None
for environment in environments:
    lock = json.loads((environment / "devenv.lock").read_text())
    nodes = lock["nodes"]
    inputs = nodes[lock["root"]]["inputs"]
    pins = {name: nodes[inputs[name]]["locked"] for name in ("devenv", "nixpkgs")}
    if reference is None:
        reference = pins
    assert pins == reference, f"Shared inputs differ in {environment.relative_to(root)}"
print(f"Verified shared input pins across {len(environments)} environments")
