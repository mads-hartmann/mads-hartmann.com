import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const sites = [
  { id: 'home', label: 'Home', href: 'https://www.mads-hartmann.com/' },
  { id: 'blog', label: 'Blog', href: 'https://blog.mads-hartmann.com/' },
  { id: 'uses', label: 'Uses', href: 'https://uses.mads-hartmann.com/' },
  { id: 'computer', label: 'Computer', href: 'https://computer.mads-hartmann.com/' },
];
const socials = [
  { label: 'GitHub', href: 'https://github.com/mads-hartmann' },
  { label: 'LinkedIn', href: 'https://www.linkedin.com/in/mads-hartmann/' },
  { label: 'Twitter', href: 'https://twitter.com/mads_hartmann' },
];
const [template, css] = await Promise.all([
  readFile(new URL('./footer.html', import.meta.url), 'utf8'),
  readFile(new URL('./footer.css', import.meta.url), 'utf8'),
]);

export function renderFooter(current) {
  if (!sites.some(site => site.id === current)) {
    throw new Error(`Unknown footer location: ${current}`);
  }
  const navigation = sites.map(({ id, label, href }) => {
    const active = id === current ? ` aria-current="${['blog', 'computer'].includes(id) ? 'location' : 'page'}"` : '';
    return `<a href="${href}"${active}>${label}</a>`;
  }).join('\n');
  const elsewhere = socials.map(({ label, href }) => `<a rel="me" href="${href}">${label}</a>`).join('\n');
  const origin = sites.find(site => site.id === current).href;
  const content = template.replace('{{sites}}', navigation).replace('{{socials}}', elsewhere)
    .replace('{{agent-guide}}', `${origin}llms.txt`);

  // The shadow tree scopes styles without browser JavaScript. Browsers without
  // Declarative Shadow DOM show the same semantic content in light DOM instead.
  return `<footer class="site-footer">
<mh-site-footer data-current="${current}">
  <template shadowrootmode="open">
    <style>${css}</style>
    ${content}
  </template>
  ${content}
</mh-site-footer>
</footer>`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.stdout.write(JSON.stringify(Object.fromEntries(sites.map(({ id }) => [id, renderFooter(id)]))));
}
