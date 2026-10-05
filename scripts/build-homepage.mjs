import { readFile, writeFile } from 'node:fs/promises';
import { renderHeader } from '../sites/shared/header/render.mjs';

const source = await readFile('sites/mads-hartmann.com/src/index.html', 'utf8');
const marker = '<!-- shared-header -->';
if (source.split(marker).length !== 2) {
  throw new Error('Homepage must contain exactly one shared-header marker');
}
await writeFile('.build/homepage/index.html', source.replace(marker, renderHeader('home')));
