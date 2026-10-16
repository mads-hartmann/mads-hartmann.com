import { execFileSync } from 'node:child_process';
execFileSync('python3', ['scripts/test_upload_immutable_assets.py'], { stdio: 'inherit' });
execFileSync(process.execPath, ['--test', 'scripts/fingerprint-assets.test.mjs'], { stdio: 'inherit' });
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createContext, runInContext } from 'node:vm';
const homepage = await readFile('.build/homepage/index.html', 'utf8');
assert(!/<script|<link[^>]+stylesheet|src=["']https?:|theme-picker/i.test(homepage));
assert(homepage.includes('https://blog.mads-hartmann.com/'));
assert(homepage.includes('https://uses.mads-hartmann.com/'));
assert.deepEqual((await readdir('.build/homepage')).sort(), ['index.html', 'index.md', 'llms.txt', 'robots.txt', 'sitemap.xml']);

function checkFooter(html, current) {
  assert.equal((html.match(/<mh-site-footer /g) || []).length, 1);
  assert(html.includes(`<mh-site-footer data-current="${current}">`));
  assert(html.includes('<template shadowrootmode="open">'));
  assert(!html.includes('<!-- shared-footer -->'));
  assert(!html.includes('mh-site-header'));
  assert(!html.includes('shared_headers'));
  assert.equal((html.match(/<footer\b/g) || []).length, 1);
  const [shadow, fallback] = html.split('<mh-site-footer ')[1].split('</template>');
  const activeHref = {
    home: 'https://www.mads-hartmann.com/',
    blog: 'https://blog.mads-hartmann.com/',
    uses: 'https://uses.mads-hartmann.com/',
    computer: 'https://computer.mads-hartmann.com/',
  }[current];
  for (const content of [shadow, fallback.split('</mh-site-footer>')[0]]) {
    assert.equal((content.match(/aria-current=/g) || []).length, 1);
    assert(content.includes(`<a href="${activeHref}" aria-current=`));
    assert(content.includes('id="footer-explore"'));
    assert(content.includes('id="footer-elsewhere"'));
    assert(content.includes(`href="${activeHref}llms.txt" type="text/plain">For agents</a>`));
    for (const href of ['https://github.com/mads-hartmann', 'https://www.linkedin.com/in/mads-hartmann/', 'https://twitter.com/mads_hartmann', 'mailto:hello@mads-hartmann.com']) {
      assert(content.includes(`href="${href}"`));
    }
    for (const href of ['https://www.mads-hartmann.com/', 'https://blog.mads-hartmann.com/', 'https://uses.mads-hartmann.com/', 'https://computer.mads-hartmann.com/']) {
      assert(content.includes(`href="${href}"`));
    }
  }
}

checkFooter(homepage, 'home');
assert(!homepage.includes('aria-labelledby="elsewhere"'));
assert(homepage.includes('>Read my blog</a>'));
assert(homepage.includes('>What I use</a>'));
const uses = await readFile('.build/uses/index.html', 'utf8');
checkFooter(uses, 'uses');
assert(!/<script|<link[^>]+stylesheet|src=["']https?:/i.test(uses));
assert.deepEqual((await readdir('.build/uses')).sort(), ['index.html', 'index.md', 'llms.txt', 'robots.txt', 'sitemap.xml']);
assert.deepEqual((await readdir('.build/computer')).sort(), ['index.html', 'index.md', 'llms.txt', 'robots.txt', 'sitemap.xml', 'v1.html', 'v1.md', 'v2.html', 'v2.md', 'v3.html', 'v3.md']);
for (const name of ['index', 'v1', 'v2', 'v3']) {
  const html = await readFile(`.build/computer/${name}.html`, 'utf8');
  checkFooter(html, 'computer');
  assert(!/<script|<link[^>]+stylesheet|src=["']https?:/i.test(html));
  assert(html.includes('<h1>Computer'));
  assert(html.includes(`href="https://computer.mads-hartmann.com${name === 'index' ? '/' : `/${name}.html`}"`));
  assert(!html.includes('DO NOT EDIT'));
  assert(!html.includes('9c3cf9a818da426f9be44d838395396c'));
  for (const link of html.matchAll(/href="(\/[^"#]*)(?:#[^"]*)?"/g)) {
    await stat(`.build/computer${link[1] === '/' ? '/index.html' : link[1]}`);
  }
  if (name === 'v3') {
    for (const id of ['heading-gitpod', 'heading-vscode', 'heading-keybindings', 'heading-raycast', 'heading-setting-up-a-new-mac', 'heading-changelog']) {
      assert(html.includes(`id="${id}"`), `Missing historical heading: ${id}`);
    }
    assert(html.includes('<details>'));
  }
}
const computerRouting = createContext({});
runInContext(await readFile('.build/routing/computer.js', 'utf8'), computerRouting);
for (const [uri, target] of Object.entries({
  '/': '/index.html', '/index.html': '/index.html',
  '/v1': '/v1.html', '/v1/': '/v1.html', '/v1.html': '/v1.html',
  '/v2': '/v2.html', '/v2/': '/v2.html', '/v2.html': '/v2.html',
  '/v3': '/v3.html', '/v3/': '/v3.html', '/v3.html': '/v3.html',
})) {
  const result = computerRouting.handler({ request: { uri, querystring: { source: { value: 'archive' } } } });
  assert.equal(result.uri, target);
  await stat(`.build/computer${target}`);
}
for (const uri of ['/unknown', '/v4', '/v1/unknown', '/css/main.css']) {
  assert.equal(computerRouting.handler({ request: { uri } }).statusCode, 404);
}
for (const content of ['OpenAI', 'Ona', 'Glitch', 'Famly', 'Issuu', 'master’s degree in Computer Science', 'University of Copenhagen', 'bachelor’s degree in Computer Science', 'IT University of Copenhagen']) {
  assert(homepage.includes(content), `Homepage is missing About content: ${content}`);
}
await assert.rejects(stat('.build/blog/about/index.html'), { code: 'ENOENT' });
// Check every rendered blog page so layouts and collection pages cannot silently
// lose the shared footer; CSS, feeds and other static files are left alone.
let blogPages = 0;
for (const file of await readdir('.build/blog', { recursive: true })) {
  if (!file.endsWith('.html')) continue;
  const html = await readFile(`.build/blog/${file}`, 'utf8');
  if (!html.includes('<html')) continue;
  checkFooter(html, 'blog');
  if (file === 'index.html') {
    assert(/<h1 class="blog-title">Blog<\/h1>\s*<div class="featured posts">/.test(html), 'Blog title must lead directly into Highlights');
    assert(!html.includes('class="back-to-blog"'));
  } else {
    assert(html.includes('<a class="back-to-blog" href="https://blog.mads-hartmann.com/">'), 'Nested blog pages must link to the blog root');
  }
  blogPages++;
}
assert(blogPages > 0);
const redirects = JSON.parse(await readFile('routing/redirects.json', 'utf8'));
const routes = redirects.homepage;
const context = createContext({});
runInContext(await readFile('.build/routing/homepage.js', 'utf8'), context);
function request(uri, host='www.mads-hartmann.com', querystring={}) {
  return context.handler({ request: { uri, headers: { host: { value: host } }, querystring } });
}
assert.equal(request('/').uri, '/index.html');
assert.equal(request('/', 'mads-hartmann.com').headers.location.value, 'https://www.mads-hartmann.com/');
for (const [from,to] of Object.entries(routes)) {
  for (const suffix of ['', '/']) {
    const result = request(from + suffix, 'mads-hartmann.com');
    assert.equal(result.statusCode,301); assert.equal(result.headers.location.value,to);
  }
  await stat('.build/blog' + new URL(to).pathname);
}
assert.equal(request('/uses/').headers.location.value,'https://uses.mads-hartmann.com/');
assert.equal(request('/blog/feed.xml').headers.location.value,'https://blog.mads-hartmann.com/feed.xml');
assert.equal(request('/blog/images/a.png').headers.location.value,'https://blog.mads-hartmann.com/images/a.png');
const query = { source: { value: 'old%20about' }, tag: { multiValue: [{ value: 'a%26b' }, { value: 'c' }] }, empty: { value: '' } };
for (const uri of [...Object.keys(routes), '/blog', '/writings', '/blog/feed.xml', '/blog/images/a.png', '/blog/uploads/a.png', '/uses', '/']) {
  const host = uri === '/' ? 'mads-hartmann.com' : 'www.mads-hartmann.com';
  const target = request(uri, host).headers.location.value;
  assert.equal(request(uri, host, query).headers.location.value, target);
}
assert.equal(request('/tools/ascii-art').statusCode,410);
assert.equal(request('/photography').statusCode,410);
assert.equal(request('/unknown').statusCode,404);
const immutablePath = '/_assets/' + 'a'.repeat(64) + '/css/site.css';
assert.equal(request(immutablePath).uri, immutablePath);
assert.equal(request('/_assets/not-a-hash/site.css').statusCode, 404);
for (const site of ['uses','blog']) {
  const ctx = createContext({});
  runInContext(await readFile(`.build/routing/${site}.js`, 'utf8'),ctx);
  assert.equal(ctx.handler({ request:{uri:'/'} }).uri,'/index.html');
  assert.equal(ctx.handler({ request:{uri:immutablePath} }).uri, immutablePath);
  if(site==='uses') assert.equal(ctx.handler({ request:{uri:'/unknown'} }).statusCode,404);
  else {
    for (const [uri, target] of Object.entries(redirects.blog)) {
      const result = ctx.handler({ request: { uri, querystring: query } });
      assert.equal(result.statusCode, 301);
      assert.equal(result.headers.location.value, target);
    }
    for (const uri of ['/about', '/about/', '/about/index.html']) {
      const result = ctx.handler({ request: { uri } });
      assert.equal(result.statusCode, 301);
      assert.equal(result.headers.location.value, 'https://www.mads-hartmann.com/');
    }
    for (const comma of [',', '%2C', '%2c']) {
      const result = ctx.handler({ request:{uri:`/sre${comma}/reliability/2021/03/14/increment-magazine.html`} });
      assert.equal(result.statusCode,301);
      assert.equal(result.headers.location.value,'/sre/2021/03/14/increment-magazine.html');
      await stat('.build/blog' + result.headers.location.value);
    }
  }
}
assert(uses.includes('Travel'));
await stat('.build/blog/feed.xml'); await stat('.build/blog/404.html');
console.log(`Sites validated; shared footer on homepage, Uses, Computer and ${blogPages} blog pages; About redirects to Home; ${Object.keys(routes).length} homepage post redirects and ${Object.keys(redirects.blog).length} blog redirects passed.`);
await import('./check-markdown.mjs');
await import('../sites/blog.mads-hartmann.com/check-images.mjs');
