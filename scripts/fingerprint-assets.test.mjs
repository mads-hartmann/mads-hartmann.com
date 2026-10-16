import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { fingerprintAssets } from './fingerprint-assets.mjs';

test('content changes propagate through CSS and HTML without losing originals', async () => {
  const root = await mkdtemp(join(tmpdir(), 'site-cache-'));
  try {
    async function build(image) {
      await rm(root, { recursive: true, force: true });
      for (const directory of ['images', 'css', 'nested']) await mkdir(join(root, directory), { recursive: true });
      await writeFile(join(root, 'images/photo.png'), image);
      await writeFile(join(root, 'css/base.css'), 'body { background: url(../images/photo.png#detail) }');
      await writeFile(join(root, 'css/main.css'), '@import "base.css"; div { background: url(../images/photo.png) }');
      await writeFile(join(root, 'nested/index.html'), '<!doctype html><html><head><link rel="stylesheet" href="/css/main.css"></head><body><img src="../images/photo.png" srcset="../images/photo.png 400w, /images/photo.png 800w"><a href="/index.md">Markdown</a><img src="https://example.com/x.png"><img src="data:image/png;base64,abcd"></body></html>');
      return fingerprintAssets(root);
    }
    const first = await build('first image');
    const second = await build('second image');
    for (const name of ['images/photo.png', 'css/base.css', 'css/main.css']) {
      assert.notEqual(first.get(name), second.get(name), `Changed dependency must invalidate ${name}`);
      const path = second.get(name);
      const bytes = await readFile(join(root, path));
      assert.equal(path.split('/')[1], createHash('sha256').update(bytes).digest('hex'));
    }
    const html = await readFile(join(root, 'nested/index.html'), 'utf8');
    assert(html.includes(`href="/${second.get('css/main.css')}"`));
    assert(html.includes(`src="/${second.get('images/photo.png')}"`));
    assert(html.includes(`/${second.get('images/photo.png')} 400w, /${second.get('images/photo.png')} 800w`));
    assert(html.includes('href="/index.md"'));
    assert(html.includes('src="https://example.com/x.png"'));
    assert(html.includes('src="data:image/png;base64,abcd"'));
    assert.equal(await readFile(join(root, 'images/photo.png'), 'utf8'), 'second image');
    assert((await readFile(join(root, second.get('css/base.css')), 'utf8')).includes(`/${second.get('images/photo.png')}#detail`));
    const third = await build('second image');
    assert.deepEqual(third, second, 'Identical builds must preserve cached URLs');
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('reject circular stylesheet imports', async () => {
  const root = await mkdtemp(join(tmpdir(), 'site-cache-'));
  try {
    await writeFile(join(root, 'a.css'), '@import "b.css"');
    await writeFile(join(root, 'b.css'), '@import "a.css"');
    await assert.rejects(fingerprintAssets(root), /Circular CSS dependency/);
  } finally { await rm(root, { recursive: true, force: true }); }
});
