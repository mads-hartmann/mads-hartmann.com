import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const links = [
  { id: 'home', label: 'Home', href: 'https://www.mads-hartmann.com/' },
  { id: 'blog', label: 'Blog', href: 'https://blog.mads-hartmann.com/' },
  { id: 'uses', label: 'Uses', href: 'https://uses.mads-hartmann.com/' },
];

const [template, css, portrait] = await Promise.all([
  readFile(new URL('./header.html', import.meta.url), 'utf8'),
  readFile(new URL('./header.css', import.meta.url), 'utf8'),
  readFile(new URL('./portrait.jpg', import.meta.url)),
]);

export function renderHeader(current) {
  if (!links.some(link => link.id === current)) {
    throw new Error(`Unknown header location: ${current}`);
  }
  const navigation = links.map(({ id, label, href }) => {
    const active = id === current ? ` aria-current="${id === 'blog' ? 'location' : 'page'}"` : '';
    return `<a href="${href}"${active}>${label}</a>`;
  }).join('\n');
  const content = template
    .replace('{{portrait}}', `data:image/jpeg;base64,${portrait.toString('base64')}`)
    .replace('{{links}}', navigation);

  // Supporting browsers render only the shadow tree. Older browsers ignore the
  // template and display the light-DOM navigation instead. Neither needs JS.
  return `<header>
<mh-site-header data-current="${current}">
  <template shadowrootmode="open">
    <style>${css}</style>
    ${content}
  </template>
  <nav aria-label="My sites">
    <a href="https://www.mads-hartmann.com/">Mads Hartmann</a>
    ${navigation}
  </nav>
</mh-site-header>
</header>`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const headers = Object.fromEntries(links.map(({ id }) => [id, renderHeader(id)]));
  process.stdout.write(JSON.stringify(headers));
}
