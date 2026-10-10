import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { parseHTML } from 'linkedom';
import TurndownService from 'turndown';
import { renderFooter } from '../shared/footer/render.mjs';

const root = fileURLToPath(new URL('.', import.meta.url));
const destination = process.argv[2] || `${root}dist`;
const origin = 'https://www.mads-hartmann.com';
const source = await readFile(`${root}src/index.html`, 'utf8');
const marker = '<!-- shared-footer -->';
if (source.split(marker).length !== 2) {
  throw new Error('Homepage must contain exactly one shared-footer marker');
}

const { document } = parseHTML(source);
const content = document.querySelector('main');
if (!content) throw new Error('Homepage must contain main content');
for (const node of content.querySelectorAll('[href], [src]')) {
  for (const attribute of ['href', 'src']) {
    const value = node.getAttribute(attribute);
    if (!value) continue;
    if (value.startsWith('data:')) {
      node.replaceWith(document.createTextNode(node.getAttribute('alt') || ''));
      break;
    }
    node.setAttribute(attribute, new URL(value, `${origin}/`).href);
  }
}
const turndown = new TurndownService({ headingStyle: 'atx', bulletListMarker: '-' });
turndown.addRule('timelineLines', {
  filter: node => /experience__(?:title|duration|location)/.test(node.getAttribute?.('class') || ''),
  replacement: content => `\n\n${content}\n\n`,
});
const markdown = `${turndown.turndown(content.innerHTML)}\n\n---\n\nCanonical page: ${origin}/\n`;
const discovery = `<link rel="alternate" type="text/markdown" href="${origin}/index.md">\n<link rel="describedby" type="text/plain" href="${origin}/llms.txt">\n`;
const html = source.replace(marker, renderFooter('home')).replace('</head>', `${discovery}</head>`);
await mkdir(destination, { recursive: true });
await writeFile(`${destination}/index.html`, html);
await writeFile(`${destination}/index.md`, markdown);
await copyFile(`${root}llms.txt`, `${destination}/llms.txt`);
