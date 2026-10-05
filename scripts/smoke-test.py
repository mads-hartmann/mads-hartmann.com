#!/usr/bin/env python3
"""Verify the deployed origin (also works before changing DNS)."""
import json, sys, time, urllib.request, urllib.error
from pathlib import Path
stack, base = sys.argv[1:]
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args): return None
opener = urllib.request.build_opener(NoRedirect)
def check(path, status=200, location=None, content=None):
    for attempt in range(8):
        try:
            try: response = opener.open(base + path, timeout=30)
            except urllib.error.HTTPError as error: response = error
            body = response.read().decode('utf-8')
            assert response.code == status, (path, response.code, status)
            if location: assert response.headers.get('Location') == location, (path,response.headers)
            if content: assert content in body, path
            return
        except (AssertionError, urllib.error.URLError):
            if attempt == 7: raise
            time.sleep(10)
check('/', content='Mads Hartmann' if stack != 'uses' else 'Uses')
for source, target in json.loads(Path('routing/redirects.json').read_text()).get(stack, {}).items():
    check(source, 301, target)
if stack == 'homepage':
    check('/', content='id="experience"')
    check('/', content='id="education"')
    check('/uses', 301, 'https://uses.mads-hartmann.com/')
    check('/blog', 301, 'https://blog.mads-hartmann.com/')
    check('/tools/ascii-art',410)
elif stack == 'blog':
    check('/feed.xml', content='<feed')
    check('/2026/01/27/using-ai-to-do-your-best-work.html',content='Using AI')
if stack in ['homepage', 'blog', 'uses']:
    current = 'home' if stack == 'homepage' else stack
    check('/', content=f'<mh-site-header data-current="{current}">')
check('/this-page-does-not-exist',404)
print(f'{stack} deployment verified at {base}')
