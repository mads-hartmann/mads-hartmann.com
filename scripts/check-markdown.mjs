import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createContext, runInContext } from 'node:vm';
import { parseHTML } from 'linkedom';
import { pageMarkdown } from './build-markdown.mjs';

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
  for (const path of ['/index.md', '/llms.txt']) {
    assert.equal(request(path).uri, path);
    assert.equal(request(path, 'text/html').uri, path);
    assert.equal(request(path, 'text/markdown').uri, path);
  }
  for (const file of await readdir(`.build/${site}`, { recursive: true })) {
    if (!file.endsWith('.html')) continue;
    const html = await readFile(`.build/${site}/${file}`, 'utf8');
    if (!/<html[\s>]/i.test(html)) continue;
    const { document } = parseHTML(html);
    const markdownPath = file.replace(/\.html$/, '.md');
    assert.equal(document.querySelectorAll('link[rel="alternate"][type="text/markdown"]').length, 1);
    assert.equal(document.querySelector('link[rel="alternate"][type="text/markdown"]').getAttribute('href'), `${origin}/${markdownPath}`);
    assert.equal(document.querySelector('link[rel="describedby"]').getAttribute('href'), `${origin}/llms.txt`);
    const markdown = await readFile(`.build/${site}/${markdownPath}`, 'utf8');
    assert(markdown.includes('Canonical page: ' + origin));
    assert(!markdown.includes('data:image/'), `${file}: embedded image bytes`);
    assert(!/<script|<style|<mh-site-header/i.test(markdown), `${file}: page chrome leaked`);
    for (const match of markdown.matchAll(/https:\/\/[^\s<>"\[\]()]+\.md/g)) {
      const url = new URL(match[0]);
      if (url.origin === origin) await stat(`.build/${site}${url.pathname}`);
    }
    assert.equal(request('/' + file, 'text/markdown').uri, '/' + markdownPath);
    assert.equal(request('/' + file, 'text/html').uri, '/' + file);
    assert.equal(request('/' + markdownPath).uri, '/' + markdownPath);
    count++;
  }
  const index = await readFile(`.build/${site}/llms.txt`, 'utf8');
  assert(index.startsWith('# '));
  for (const [, target] of index.matchAll(/\]\((https:[^)]+)\)/g)) {
    const url = new URL(target);
    const targetSite = Object.keys(origins).find(key => origins[key] === url.origin);
    assert(targetSite, `Unexpected llms.txt target: ${target}`);
    await stat(`.build/${targetSite}${url.pathname}`);
  }
  if (site === 'blog') {
    for (const path of ['/series/observability', '/series/observability/']) assert.equal(request(path, 'text/markdown').uri, '/series/observability/index.md');
    for (const path of ['/feed.xml', '/images/profile.png', '/css/index.css', '/llms.txt']) assert.equal(request(path, 'text/markdown').uri, path);
    assert.equal(request('/about', 'text/markdown').headers.location.value, origins.homepage + '/');
  } else {
    assert.equal(request('/unknown', 'text/markdown').statusCode, 404);
    assert.equal(request('/unknown.md', 'text/markdown').statusCode, 404);
  }
  if (site === 'homepage') {
    for (const path of ['/index.md', '/llms.txt']) assert.equal(request(path, 'text/markdown', 'mads-hartmann.com').headers.location.value, origin + path);
    assert.equal(request('/tools/ascii-art', 'text/markdown').statusCode, 410);
  }
}

// Exercise the content structures that could lose meaning during conversion.
const sample = pageMarkdown(`<!doctype html><html><head><title>Example</title></head><body>
<nav>Not article content</nav><main><h1>Example &amp; code</h1>
<p><a href="../other.html">Other article</a> <a href="#note">Footnote</a></p>
<div class="language-sh highlighter-rouge"><pre><code>echo '&lt;tag&gt; &amp; value'
\`\`\`
</code></pre></div>
<table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>One</td><td>Two</td></tr></tbody></table>
<details><summary>More detail</summary><p>Still readable</p></details>
<img src="/images/example.png" alt="Useful diagram"><img src="data:image/png;base64,abc" alt="Portrait">
<audio controls><source src="/recording.mp3"></audio><iframe src="https://example.net/video" title="Conference talk"></iframe>
<script>Not article code</script></main></body></html>`, 'https://example.com/docs/article.html', new Map([['https://example.com/other.html', 'https://example.com/other.md']]));
for (const expected of ['# Example & code', '[Other article](https://example.com/other.md)', '[Footnote](https://example.com/docs/article.html#note)', "````sh\necho '<tag> & value'\n```\n````", '| Name | Value |', '| One | Two |', 'More detail', 'Still readable', '![Useful diagram](https://example.com/images/example.png)', 'Portrait', '(https://example.com/recording.mp3)', '[Conference talk](https://example.net/video)']) assert(sample.includes(expected), `Missing: ${expected}\n${sample}`);
assert(!sample.includes('Not article'));

const article = await readFile('.build/blog/2026/01/27/using-ai-to-do-your-best-work.md', 'utf8');
assert(article.includes('# Using AI to do your best work'));
assert(article.includes('27 Jan 2026'));
assert(article.includes('## A worthy bug'));
assert(article.includes('jsonl'));
assert((await readFile('.build/blog/sre/2020/05/07/feelings-during-incident-response.md', 'utf8')).includes('https://blog.mads-hartmann.com/uploads/feelings-during-incident-response.mp3'));
const homepage = await readFile('.build/homepage/index.md', 'utf8');
for (const value of ['OpenAI', 'Ona', 'Glitch', 'Famly', 'Issuu', 'Experience', 'Education']) assert(homepage.includes(value));
console.log(`Markdown validated: ${count} pages, three llms.txt indexes, discovery links, content preservation, and negotiated routes.`);
