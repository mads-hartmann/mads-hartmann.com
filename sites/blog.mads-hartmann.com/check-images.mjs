import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import sharp from 'sharp';

let count = 0;
for (const file of await readdir('.build/blog', { recursive: true })) {
  if (!file.endsWith('.html')) continue;
  const html = await readFile(`.build/blog/${file}`, 'utf8');
  assert(!html.includes('<p>&lt;/a&gt;</p>'), `${file}: image link must not leak markup`);
  const images = [...html.matchAll(/<img\b[^>]*>/g)].map(([tag]) =>
    Object.fromEntries([...tag.matchAll(/([\w-]+)="([^"]*)"/g)].map(([, key, value]) => [key, value])));
  for (const image of images) {
    if (!/^\/(?:_assets\/[a-f0-9]+\/)?images\//.test(image.src ?? '')) continue;
    assert(image.src.endsWith('.webp'), `${file}: local content image needs optimization`);
    assert(+image.width > 0 && +image.height > 0, `${file}: reserve image space`);
    assert(image.alt, `${file}: describe the screenshot`);
    assert(image.sizes && image.srcset, `${file}: responsive candidates missing`);
    await stat(`.build/blog${image.src}`);
    let previous = 0;
    for (const candidate of image.srcset.split(', ')) {
      const [url, descriptor] = candidate.split(' ');
      const width = Number.parseInt(descriptor);
      const actual = await sharp(`.build/blog${url}`).metadata();
      assert.equal(actual.width, width, `${file}: incorrect width descriptor`);
      assert(width > previous && width <= Math.min(+image.width, 1536), `${file}: invalid candidate size`);
      assert(Math.abs(actual.height - width * image.height / image.width) <= 1, `${file}: changed aspect ratio`);
      previous = width;
    }
    count++;
  }
  if (file.endsWith('/gitpod-cli.html')) {
    assert.deepEqual(images.map(image => image.loading), ['eager', 'lazy', 'lazy', 'lazy']);
  }
  if (file.endsWith('/emacs-tree-view.html')) assert.equal(images[0].loading, 'eager');
}
assert(count >= 8, 'Expected the existing eight article screenshots');
console.log(`Validated dimensions, responsive assets and loading policy for ${count} blog images.`);
