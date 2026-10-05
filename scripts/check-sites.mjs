import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createContext, runInContext } from 'node:vm';
const homepage = await readFile('.build/homepage/index.html', 'utf8');
assert(!/<script|<link[^>]+stylesheet|src=["']https?:|theme-picker/i.test(homepage));
assert(homepage.includes('data:image/jpeg;base64,'));
assert(homepage.includes('https://blog.mads-hartmann.com/'));
assert(homepage.includes('https://uses.mads-hartmann.com/'));
assert.deepEqual(await readdir('.build/homepage'), ['index.html']);

function checkHeader(html, current) {
  assert.equal((html.match(/<mh-site-header /g) || []).length, 1);
  assert(html.includes(`<mh-site-header data-current="${current}">`));
  assert(html.includes('<template shadowrootmode="open">'));
  assert(!html.includes('<!-- shared-header -->'));
  const [shadow, fallback] = html.split('<mh-site-header ')[1].split('</template>');
  const activeHref = {
    home: 'https://www.mads-hartmann.com/',
    blog: 'https://blog.mads-hartmann.com/',
    uses: 'https://uses.mads-hartmann.com/',
  }[current];
  for (const content of [shadow, fallback.split('</mh-site-header>')[0]]) {
    assert.equal((content.match(/aria-current=/g) || []).length, 1);
    assert(content.includes(`<a href="${activeHref}" aria-current=`));
    assert(!content.includes('>About</a>'));
    for (const href of ['https://www.mads-hartmann.com/', 'https://blog.mads-hartmann.com/', 'https://uses.mads-hartmann.com/']) {
      assert(content.includes(`href="${href}"`));
    }
  }
}

checkHeader(homepage, 'home');
const uses = await readFile('.build/uses/index.html', 'utf8');
checkHeader(uses, 'uses');
assert(!/<script|<link[^>]+stylesheet|src=["']https?:/i.test(uses));
assert.deepEqual(await readdir('.build/uses'), ['index.html']);
for (const content of ['id="experience"', 'id="education"', 'Ona', 'Glitch', 'Famly', 'Issuu', 'Masters degree in Computer Science', 'Bachelors degree in Computer Science']) {
  assert(homepage.includes(content), `Homepage is missing About content: ${content}`);
}
await assert.rejects(stat('.build/blog/about/index.html'), { code: 'ENOENT' });
// Check every rendered blog page so layouts and collection pages cannot silently
// lose the shared header; CSS, feeds and other static files are left alone.
let blogPages = 0;
for (const file of await readdir('.build/blog', { recursive: true })) {
  if (!file.endsWith('.html')) continue;
  const html = await readFile(`.build/blog/${file}`, 'utf8');
  if (!html.includes('<html')) continue;
  checkHeader(html, 'blog');
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
// CloudFront query keys and values retain their incoming URL encoding.
const queryCases = [
  ['source=old%20about&tag=a%26b&tag=c', { source: { value: 'old%20about' }, tag: { value: 'a%26b', multiValue: [{ value: 'a%26b' }, { value: 'c' }] } }],
  ['space+key=hello+world&percent=%2520&empty=', { 'space+key': { value: 'hello+world' }, percent: { value: '%2520' }, empty: { value: '' } }],
  ['na%26me=%C3%A6%2F%3F%23%25&tag=a%3Db&tag=', { 'na%26me': { value: '%C3%A6%2F%3F%23%25' }, tag: { value: 'a%3Db', multiValue: [{ value: 'a%3Db' }, { value: '' }] } }],
];
for (const uri of [...Object.keys(routes), '/blog', '/writings', '/blog/feed.xml', '/blog/images/a.png', '/blog/uploads/a.png', '/uses', '/']) {
  const host = uri === '/' ? 'mads-hartmann.com' : 'www.mads-hartmann.com';
  const target = request(uri, host).headers.location.value;
  for (const [raw, query] of queryCases) {
    assert.equal(request(uri, host, query).headers.location.value, target + '?' + raw);
  }
}
assert.equal(request('/tools/ascii-art').statusCode,410);
assert.equal(request('/photography').statusCode,410);
assert.equal(request('/unknown').statusCode,404);
for (const site of ['uses','blog']) {
  const ctx = createContext({});
  runInContext(await readFile(`.build/routing/${site}.js`, 'utf8'),ctx);
  assert.equal(ctx.handler({ request:{uri:'/'} }).uri,'/index.html');
  if(site==='uses') assert.equal(ctx.handler({ request:{uri:'/unknown'} }).statusCode,404);
  else {
    for (const [uri, target] of Object.entries(redirects.blog)) {
      const result = ctx.handler({ request: { uri, querystring: { source: { value: 'old%20link' }, tag: { multiValue: [{ value: 'a%26b' }, { value: 'c' }] } } } });
      assert.equal(result.statusCode, 301);
      assert.equal(result.headers.location.value, target + '?source=old%20link&tag=a%26b&tag=c');
      for (const [raw, query] of queryCases) {
        const response = ctx.handler({ request: { uri, querystring: query } });
        assert.equal(response.statusCode, 301);
        assert.equal(response.headers.location.value, target + '?' + raw);
      }
    }
    for (const uri of ['/about', '/about/', '/about/index.html']) {
      const result = ctx.handler({ request: { uri } });
      assert.equal(result.statusCode, 301);
      assert.equal(result.headers.location.value, 'https://www.mads-hartmann.com/');
      const withQuery = ctx.handler({ request: { uri, querystring: { source: { value: 'old%20about' }, tag: { multiValue: [{ value: 'a%26b' }, { value: 'c' }] } } } });
      assert.equal(withQuery.headers.location.value, 'https://www.mads-hartmann.com/?source=old%20about&tag=a%26b&tag=c');
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
console.log(`Sites validated; shared header on homepage, Uses and ${blogPages} blog pages; About redirects to Home; ${Object.keys(routes).length} homepage post redirects and ${Object.keys(redirects.blog).length} blog redirects passed.`);
