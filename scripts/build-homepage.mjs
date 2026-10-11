import { readFile, writeFile } from 'node:fs/promises';
import { renderFooter } from '../sites/shared/footer/render.mjs';

const source = await readFile('sites/mads-hartmann.com/src/index.html', 'utf8');
const marker = '<!-- shared-footer -->';
if (source.split(marker).length !== 2) {
  throw new Error('Homepage must contain exactly one shared-footer marker');
}
await writeFile('.build/homepage/index.html', source.replace(marker, renderFooter('home')));
