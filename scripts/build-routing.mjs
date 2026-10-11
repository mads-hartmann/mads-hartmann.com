import { readFile, mkdir, writeFile } from 'node:fs/promises';
const redirects = JSON.parse(await readFile('routing/redirects.json', 'utf8'));
const markdown = await readFile('routing/markdown.js', 'utf8');
await mkdir('.build/routing', { recursive: true });
for (const site of ['homepage', 'blog', 'uses']) {
  const template = await readFile(`routing/${site}.js`, 'utf8');
  const source = markdown + '\n' + template.replace('__REDIRECTS__', JSON.stringify(redirects[site] || {}));
  if (Buffer.byteLength(source) > 10240) throw new Error(`${site} CloudFront function exceeds 10 KB`);
  await writeFile(`.build/routing/${site}.js`, source);
}
