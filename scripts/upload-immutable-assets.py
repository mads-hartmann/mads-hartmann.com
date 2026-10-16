#!/usr/bin/env python3
"""Append-only publication: old content-addressed objects must never be deleted."""
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from pathlib import Path
import json
import os
import subprocess


def upload(directory, bucket, mime_types, cache_control):
    directory = Path(directory)
    files = sorted(path for path in directory.glob('_assets/**/*') if path.is_file())
    # Validate the entire set before any writes. CSS hashes include rewritten dependencies.
    for path in files:
        key = path.relative_to(directory).as_posix()
        if key.split('/')[1] != sha256(path.read_bytes()).hexdigest():
            raise ValueError(f'Asset bytes do not match immutable URL: {key}')

    def publish(path):
        key = path.relative_to(directory).as_posix()
        subprocess.run([
            'aws', 's3', 'cp', str(path), f's3://{bucket}/{key}',
            '--content-type', mime_types.get(path.suffix[1:].lower(), 'application/octet-stream'),
            '--cache-control', cache_control, '--only-show-errors',
        ], check=True)

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(publish, files))
    print(f'Published {len(files)} immutable assets; prior versions retained')


if __name__ == '__main__':
    upload(os.environ['CONTENT_DIRECTORY'], os.environ['BUCKET_NAME'],
           json.loads(os.environ['MIME_TYPES']), os.environ['CACHE_CONTROL'])
