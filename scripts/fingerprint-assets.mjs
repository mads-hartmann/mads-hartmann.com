import { createHash } from 'node:crypto';
import { readFile, readdir, mkdir, writeFile, rm } from 'node:fs/promises';
import { posix, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseHTML } from 'linkedom';

// Original URLs remain available for feeds, Markdown, bookmarks and old HTML.
// Only generated content-addressed copies receive immutable cache headers.
export async function fingerprintAssets(directory) {
  await rm(`${directory}/_assets`, { recursive: true, force: true });
  const files = (await readdir(directory, { recursive: true })).sort();
  const assets = new Set(files.filter(file => /\.(?:css|js|png|jpe?g|gif|svg|ico|webp|avif|woff2?|ttf|otf|mp3|m4a|mp4|pdf)$/i.test(file)));
  const generated = new Map();
  const visiting = new Set();

  async function rewriteURL(value, source) {
    // Leave other origins, data URLs, fragments and existing query semantics alone.
    if (!value || /^(?:[a-z][\w+.-]*:|\/\/|#)/i.test(value)) return value;
    const url = new URL(value, `https://site.invalid/${source}`);
    const path = decodeURIComponent(url.pathname.slice(1));
    if (!assets.has(path)) return value;
    return `/${(await fingerprint(path)).split('/').map(encodeURIComponent).join('/')}${url.search}${url.hash}`;
  }
  async function replaceAsync(text, pattern, replacement) {
    const matches = [...text.matchAll(pattern)];
    const replacements = [];
    for (const match of matches) replacements.push(await replacement(match));
    for (let index = matches.length - 1; index >= 0; index--) {
      const match = matches[index];
      text = text.slice(0, match.index) + replacements[index] + text.slice(match.index + match[0].length);
    }
    return text;
  }
  async function rewriteCSS(text, source) {
    // Resolve dependencies before hashing the CSS, so a changed font/image also
    // changes its stylesheet URL. Reject cycles rather than publish unstable URLs.
    text = await replaceAsync(text, /url\(\s*(['"]?)([^'"()]*?)\1\s*\)/gi,
      async match => `url("${await rewriteURL(match[2].trim(), source)}")`);
    return replaceAsync(text, /@import\s+(['"])([^'"]+)\1/gi,
      async match => `@import "${await rewriteURL(match[2], source)}"`);
  }
  async function fingerprint(file) {
    if (generated.has(file)) return generated.get(file);
    if (visiting.has(file)) throw new Error(`Circular CSS dependency: ${file}`);
    visiting.add(file);
    let contents = await readFile(`${directory}/${file}`);
    if (file.endsWith('.css')) contents = Buffer.from(await rewriteCSS(contents.toString('utf8'), file));
    const digest = createHash('sha256').update(contents).digest('hex');
    const destination = `_assets/${digest}/${file}`;
    await mkdir(posix.dirname(`${directory}/${destination}`), { recursive: true });
    await writeFile(`${directory}/${destination}`, contents);
    generated.set(file, destination);
    visiting.delete(file);
    return destination;
  }
  // Sequential traversal also avoids mistaking concurrent references for cycles.
  for (const file of assets) await fingerprint(file);
  for (const file of files.filter(file => file.endsWith('.html'))) {
    const original = await readFile(`${directory}/${file}`, 'utf8');
    const { document } = parseHTML(original);
    let changed = false;
    for (const element of document.querySelectorAll('[src], [href], [poster], [srcset], [style], style')) {
      for (const attribute of ['src', 'href', 'poster']) {
        if (!element.hasAttribute(attribute)) continue;
        const before = element.getAttribute(attribute);
        const after = await rewriteURL(before, file);
        if (after !== before) { element.setAttribute(attribute, after); changed = true; }
      }
      if (element.hasAttribute('srcset')) {
        const before = element.getAttribute('srcset');
        // Data URL candidates can contain commas; leave those srcsets untouched.
        if (!before.includes('data:')) {
          const after = (await Promise.all(before.split(',').map(async candidate => {
            const [url, ...descriptor] = candidate.trim().split(/\s+/);
            return [await rewriteURL(url, file), ...descriptor].join(' ');
          }))).join(', ');
          if (after !== before) { element.setAttribute('srcset', after); changed = true; }
        }
      }
      for (const attribute of element.localName === 'style' ? ['textContent'] : ['style']) {
        const before = attribute === 'textContent' ? element.textContent : element.getAttribute(attribute);
        if (!before) continue;
        const after = await rewriteCSS(before, file);
        if (after !== before) {
          if (attribute === 'textContent') element.textContent = after;
          else element.setAttribute(attribute, after);
          changed = true;
        }
      }
    }
    if (changed) await writeFile(`${directory}/${file}`, document.toString());
  }
  return generated;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  for (const directory of process.argv.slice(2)) {
    const generated = await fingerprintAssets(directory);
    console.log(`${directory}: fingerprinted ${generated.size} assets`);
  }
}
