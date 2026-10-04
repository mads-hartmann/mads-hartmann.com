import { readFile, mkdir, writeFile } from 'node:fs/promises';
const routes = JSON.parse(await readFile('routing/blog-redirects.json', 'utf8'));
const template = await readFile('routing/homepage.js', 'utf8');
const source = template.replace('__BLOG_REDIRECTS__', JSON.stringify(routes));
if (Buffer.byteLength(source) > 10240) throw new Error('CloudFront function exceeds 10 KB');
await mkdir('.build/routing', { recursive: true });
await writeFile('.build/routing/homepage.js', source);
for (const site of ['blog', 'uses']) await writeFile(`.build/routing/${site}.js`, await readFile(`routing/${site}.js`));
