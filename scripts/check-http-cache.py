#!/usr/bin/env python3
"""Post-deploy cache contract; no cache bypass or production mutations."""
import re
import sys
import urllib.error
import urllib.request


def request(base, path, headers=None):
    try:
        response = urllib.request.urlopen(urllib.request.Request(base + path, headers=headers or {}), timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    return response.code, response.headers, response.read()


def check(base):
    status, headers, html = request(base, '/')
    assert status == 200, status
    assert headers.get('Cache-Control') == 'public,max-age=0,s-maxage=3600,must-revalidate', headers
    paths = ['/']
    asset = re.search(rb'(?:src|href)="(/_assets/[^" ]+)"', html)
    if asset:
        path = asset[1].decode()
        status, headers, _ = request(base, path)
        assert status == 200, (path, status)
        assert headers.get('Cache-Control') == 'public,max-age=31536000,immutable', headers
        paths.append(path)
    for path in paths:
        for encoding in ['identity', 'gzip', 'br']:
            accept = {'Accept-Encoding': encoding}
            status, headers, _ = request(base, path, accept)
            assert status == 200, (path, status)
            etag, modified = headers.get('ETag'), headers.get('Last-Modified')
            assert etag and modified, (path, headers)
            status, _, body = request(base, path, {**accept, 'If-None-Match': etag})
            assert status == 304 and not body, (path, encoding, 'If-None-Match', status)
            status, _, body = request(base, path, {**accept, 'If-Modified-Since': modified})
            assert status == 304 and not body, (path, encoding, 'If-Modified-Since', status)
            # If-None-Match takes precedence over the date validator.
            status, _, _ = request(base, path, {**accept, 'If-None-Match': '"not-the-current-version"', 'If-Modified-Since': modified})
            assert status == 200, (path, encoding, 'validator precedence', status)
            # CloudFront may skip compression opportunistically. Report the
            # observed encoding; Terraform checks verify both formats are enabled.
            print(f'{path}: requested {encoding}, served {headers.get("Content-Encoding", "identity")}, validators passed')
    print(f'Cache contract verified at {base}')


if __name__ == '__main__':
    check(sys.argv[1].rstrip('/'))
