import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createContext, runInContext } from 'node:vm';

const origins = {
  homepage: 'https://www.mads-hartmann.com',
  blog: 'https://blog.mads-hartmann.com',
  uses: 'https://uses.mads-hartmann.com',
};
let count = 0;
for (const [site, origin] of Object.entries(origins)) {
  const context = createContext({});
  const source = await readFile(`.build/routing/${site}.js`, 'utf8');
  assert(Buffer.byteLength(source) <= 10240, `${site} exceeds the CloudFront function size limit`);
  runInContext(source, context);
  const request = (uri, accept, host = new URL(origin).host) => context.handler({ request: {
    uri, headers: { host: { value: host }, ...(accept === undefined ? {} : { accept: typeof accept === 'string' ? { value: accept } : accept }) },
  } });
  const acceptCases = [
    [undefined, false], ['', false], ['*/*', false], ['text/*', false],
    ['text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8', false],
    ['text/markdown', true], ['text/markdown; charset=utf-8', true],
    ['TEXT/MARKDOWN;Q=1', true], ['text/markdown, text/html', true],
    ['text/markdown;q=0.4,text/html;q=0.8', false],
    ['text/markdown;q=0.8,text/html;q=0.4', true],
    ['text/markdown;q=0.5,*/*;q=0.8', false],
    ['text/markdown;q=0.5,text/html;q=0.1,*/*;q=1', true],
    ['text/markdown;q=0.5,text/*;q=0.8,*/*;q=0.1', false],
    ['text/markdown;q=0', false], ['text/markdown;q=0,*/*;q=1', false],
    ['text/markdown;q=broken', false], ['text/markdown;q=1.1', false],
    ['text/markdown;q=-1', false],
    [{ value: 'text/html;q=0.4', multiValue: [{ value: 'text/html;q=0.4' }, { value: 'text/markdown;q=0.8' }] }, true],
  ];
  for (const [accept, markdown] of acceptCases) {
    for (const uri of ['/', '/index.html']) assert.equal(request(uri, accept).uri, markdown ? '/index.md' : '/index.html', `${site}: ${JSON.stringify(accept)}`);
  }
  for (const path of ['/index.md', '/llms.txt', '/robots.txt', '/sitemap.xml']) {
    assert.equal(request(path).uri, path);
    assert.equal(request(path, 'text/html').uri, path);
    assert.equal(request(path, 'text/markdown').uri, path);
  }
  for (const file of await readdir(`.build/${site}`, { recursive: true })) {
    if (!file.endsWith('.html')) continue;
    const html = await readFile(`.build/${site}/${file}`, 'utf8');
    if (!/<html[\s>]/i.test(html)) continue;
    const markdownPath = site === 'blog' && file.endsWith('/index.html')
      ? file.replace(/\/index\.html$/, '.md') : file.replace(/\.html$/, '.md');
    const alternates = [...html.matchAll(/<link\b[^>]*>/g)].map(([tag]) => tag)
      .filter(tag => /\brel="alternate"/.test(tag) && /\btype="text\/markdown"/.test(tag));
    assert.equal(alternates.length, 1);
    const href = /\bhref="([^"]+)"/.exec(alternates[0])[1];
    assert.equal(new URL(href, origin).href, `${origin}/${markdownPath}`);
    assert(html.includes(`rel="describedby" type="text/plain" href="${origin}/llms.txt"`));
    const markdown = await readFile(`.build/${site}/${markdownPath}`, 'utf8');
    assert(markdown.includes('Canonical page: ' + origin));
    assert(!markdown.includes('data:image/'), `${file}: embedded image bytes`);
    assert(!/<script|<style|<mh-site-(?:header|footer)/i.test(markdown), `${file}: page chrome leaked`);
    if (site === 'blog') {
      const references = [...markdown.matchAll(/\[\^(\d+)\](?!:)/g)].map(match => match[1]);
      const definitions = [...markdown.matchAll(/^\[\^(\d+)\]:/gm)].map(match => match[1]);
      assert.deepEqual(new Set(references), new Set(definitions), `${file}: unresolved footnotes`);
      assert.equal(definitions.length, new Set(definitions).size, `${file}: duplicate footnote definitions`);
      assert(!/\]\((?:\/|#fn:|#fnref:)/.test(markdown), `${file}: relative or broken footnote link`);
    }
    for (const match of markdown.matchAll(/https:\/\/[^\s<>"\[\]()]+\.md/g)) {
      const url = new URL(match[0]);
      if (url.origin === origin) await stat(`.build/${site}${url.pathname}`);
    }
    assert.equal(request('/' + file, 'text/markdown').uri, '/' + markdownPath);
    assert.equal(request('/' + file, 'text/html').uri, '/' + file);
    assert.equal(request('/' + markdownPath).uri, '/' + markdownPath);
    if (site === 'blog' && file.endsWith('/index.html')) {
      const directory = '/' + file.slice(0, -'index.html'.length);
      for (const uri of [directory, directory.slice(0, -1)]) {
        for (const [accept, wantsMarkdown] of acceptCases) {
          assert.equal(request(uri, accept).uri, '/' + (wantsMarkdown ? markdownPath : file));
        }
      }
    }
    count++;
  }
  const index = await readFile(`.build/${site}/llms.txt`, 'utf8');
  const sourceDirectory = new URL(origin).hostname.replace(/^www\./, '');
  assert.equal(index, await readFile(`sites/${sourceDirectory}/llms.txt`, 'utf8'), `${site}: publish the tracked llms.txt unchanged`);
  assert(index.startsWith('# '));
  for (const [, target] of index.matchAll(/\]\((https:[^)]+)\)/g)) {
    const url = new URL(target);
    const targetSite = Object.keys(origins).find(key => origins[key] === url.origin);
    assert(targetSite, `Unexpected llms.txt target: ${target}`);
    await stat(`.build/${targetSite}${url.pathname}`);
  }
  if (site === 'blog') {
    for (const path of ['/series/observability', '/series/observability/']) assert.equal(request(path, 'text/markdown').uri, '/series/observability.md');
    for (const path of ['/feed.xml', '/images/profile.png', '/css/index.css', '/llms.txt']) assert.equal(request(path, 'text/markdown').uri, path);
    assert.equal(request('/about', 'text/markdown').headers.location.value, origins.homepage + '/');
  } else {
    const robots = await readFile(`.build/${site}/robots.txt`, 'utf8');
    assert(robots.includes(`Sitemap: ${origin}/sitemap.xml`));
    assert(robots.includes('User-agent: *\nAllow: /'));
    const sitemap = await readFile(`.build/${site}/sitemap.xml`, 'utf8');
    assert(sitemap.includes('xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'));
    assert(sitemap.includes(`<loc>${origin}/</loc>`));
    assert.equal(request('/unknown', 'text/markdown').statusCode, 404);
    assert.equal(request('/unknown.md', 'text/markdown').statusCode, 404);
  }
  if (site === 'homepage') {
    for (const path of ['/index.md', '/llms.txt', '/robots.txt', '/sitemap.xml']) assert.equal(request(path, 'text/markdown', 'mads-hartmann.com').headers.location.value, origin + path);
    assert.equal(request('/tools/ascii-art', 'text/markdown').statusCode, 410);
  }
}

assert.equal(await readFile('.build/uses/index.md', 'utf8'), `${(await readFile('sites/uses.mads-hartmann.com/index.md', 'utf8')).trimEnd()}\n\n---\n\nCanonical page: https://uses.mads-hartmann.com/\n`);

const article = await readFile('.build/blog/2026/01/27/using-ai-to-do-your-best-work.md', 'utf8');
assert(article.includes('# Using AI to do your best work'));
assert(article.includes('27 Jan 2026'));
assert(article.includes('## A worthy bug'));
assert(article.includes('jsonl'));
assert(article.includes('[^1]'));
assert(article.includes('\n[^1]: This prompt'));
assert(!article.includes('#fn:') && !article.includes('#fnref:'));
const archive = await readFile('.build/blog/index.md', 'utf8');
assert(archive.includes('](https://blog.mads-hartmann.com/2026/01/27/using-ai-to-do-your-best-work.md) — 27 Jan 2026'));
assert(archive.includes('](https://blog.mads-hartmann.com/series/observability.md) — 2019 - 2020'));
const awk = await readFile('.build/blog/2018/09/29/enough-awk-to-get-by.md', 'utf8');
assert(awk.includes('[^3]'));
assert(awk.includes('\n[^3]: [The A-Z of Programming Languages: AWK]'));
assert(awk.includes('https://blog.mads-hartmann.com/2018/09/29/enough-awk-to-get-by.html#explaining-the-example'));
assert(awk.includes("grep -R TRIGGER . | awk '{gsub(/:.*/,\" \")}1'"));
const usesSource = await readFile('sites/uses.mads-hartmann.com/index.md', 'utf8');
const contentUpdated = usesSource.match(/^Content updated: (\d{4}-\d{2}-\d{2})\.$/m);
assert(contentUpdated, 'Uses must carry an explicit content update date');
assert((await readFile('.build/uses/index.html', 'utf8')).includes(contentUpdated[0]));
assert((await readFile('.build/blog/sre/2020/05/07/feelings-during-incident-response.md', 'utf8')).includes('https://blog.mads-hartmann.com/uploads/feelings-during-incident-response.mp3'));
const homepage = await readFile('.build/homepage/index.md', 'utf8');
for (const value of ['OpenAI', 'Ona', 'Glitch', 'Famly', 'Issuu', 'University of Copenhagen', 'IT University of Copenhagen']) assert(homepage.includes(value));
console.log(`Markdown validated: ${count} pages, three llms.txt indexes, discovery links, content preservation, and negotiated routes.`);
