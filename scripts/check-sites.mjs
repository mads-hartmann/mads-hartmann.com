import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { createContext, runInContext } from 'node:vm';
const homepage = await readFile('.build/homepage/index.html', 'utf8');
assert(!/<script|<link[^>]+stylesheet|src=["']https?:|theme-picker/i.test(homepage));
assert(homepage.includes('data:image/png;base64,'));
assert(homepage.includes('https://blog.mads-hartmann.com/'));
assert(homepage.includes('https://uses.mads-hartmann.com/'));
assert.deepEqual(await readdir('.build/homepage'), ['index.html']);
const routes = JSON.parse(await readFile('routing/blog-redirects.json', 'utf8'));
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
assert.equal(request('/blog/2017', 'www.mads-hartmann.com', { a: { multiValue: [{value:'hello world'}, {value:'x&y'}] } }).headers.location.value, routes['/blog/2017'] + '?a=hello%20world&a=x%26y');
assert.equal(request('/tools/ascii-art').statusCode,410);
assert.equal(request('/photography').statusCode,410);
assert.equal(request('/unknown').statusCode,404);
for (const site of ['uses','blog']) {
  const ctx = createContext({});
  runInContext(await readFile(`.build/routing/${site}.js`, 'utf8'),ctx);
  assert.equal(ctx.handler({ request:{uri:'/'} }).uri,'/index.html');
  if(site==='uses') assert.equal(ctx.handler({ request:{uri:'/unknown'} }).statusCode,404);
  else assert.equal(ctx.handler({ request:{uri:'/about/'} }).uri,'/about/index.html');
}
assert((await readFile('.build/uses/index.html','utf8')).includes('Travel'));
await stat('.build/blog/feed.xml'); await stat('.build/blog/404.html');
console.log(`Sites validated; ${Object.keys(routes).length} migrated post URLs match generated blog files.`);
