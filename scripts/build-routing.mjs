import { readFile, mkdir, writeFile } from 'node:fs/promises';
const redirects = JSON.parse(await readFile('routing/redirects.json', 'utf8'));
const markdown = await readFile('routing/markdown.js', 'utf8');
const selected = process.argv[2] || 'all';
const destination = process.argv[3] || '.build/routing';
await mkdir(destination, { recursive: true });
for (const site of (selected === 'all' ? ['homepage', 'blog', 'uses', 'computer'] : [selected])) {
  const template = await readFile(`routing/${site}.js`, 'utf8');
  const source = markdown + '\n' + template.replace('__REDIRECTS__', JSON.stringify(redirects[site] || {}));
  if (Buffer.byteLength(source) > 10240) throw new Error(`${site} CloudFront function exceeds 10 KB`);
  await writeFile(`${destination}/${site}.js`, source);
}
