"""Content identities: no Git revision, tool version, timestamp or absolute path."""

import hashlib
import json
from pathlib import Path
import sys


def digest_files(files):
    # Hash an unambiguous, sorted list of relative names and byte digests. This
    # includes additions, deletions and renames, but excludes filesystem metadata.
    entries = [[name, hashlib.sha256(path.read_bytes()).hexdigest()]
               for name, path in sorted(files)]
    encoded = json.dumps(entries, ensure_ascii=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def manifest(site, content, routing, infrastructure):
    identities = {
        "content_digest": digest_files((p.relative_to(content).as_posix(), p)
                                       for p in content.rglob("*") if p.is_file()),
        "routing_digest": digest_files([(site + ".js", routing)]),
        "infrastructure_digest": digest_files((p.as_posix(), p) for p in infrastructure),
    }
    identity = json.dumps(identities, sort_keys=True, separators=(",", ":")).encode()
    return {"schema_version": 1, "site": site, **identities,
            "bundle_digest": "sha256:" + hashlib.sha256(identity).hexdigest()}


if __name__ == "__main__":
    site, content, routing, output, *infrastructure = sys.argv[1:]
    result = manifest(site, Path(content), Path(routing), [Path(p) for p in infrastructure])
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
