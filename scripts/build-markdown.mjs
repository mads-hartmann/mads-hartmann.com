import { readFile, readdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseHTML } from 'linkedom';
import TurndownService from 'turndown';
import { gfm } from 'turndown-plugin-gfm';

const sites = {
  homepage: {
    origin: 'https://www.mads-hartmann.com',
    title: 'Mads Hartmann',
    description: 'Software engineer and tech lead focused on reliability. Biography, experience, education, and publications.',
    pages: [['index.md', 'About Mads Hartmann', 'Biography, experience, education, and publications.']],
  },
  uses: {
    origin: 'https://uses.mads-hartmann.com',
    title: 'Uses — Mads Hartmann',
    description: 'The hardware, software, and equipment Mads Hartmann uses.',
    pages: [['index.md', 'Uses', 'Hardware, software, and equipment.']],
  },
  blog: {
    origin: 'https://blog.mads-hartmann.com',
    title: "Mads Hartmann's Blog",
    description: 'Writing about software engineering, reliability, observability, and developer tools.',
    pages: [
      ['index.md', 'All posts', 'Chronological archive with links to every published post.'],
      ['series/observability/index.md', 'Journey into Observability', 'A series on observability tools and practices.'],
      ['book-reviews/index.md', 'Book reviews', 'Index of book reviews.'],
      ['talks/index.md', 'Conference talks', 'Talk descriptions and recordings.'],
    ],
  },
};

const turndown = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-' });
turndown.use(gfm);
// Rouge puts the language on a wrapper and spans inside <code>. Preserve the
// actual code text and choose a fence that cannot be closed by its contents.
turndown.addRule('codeBlocks', {
  filter: 'pre',
  replacement(_content, node) {
    const code = node.querySelector('code') || node;
    let language = '';
    for (let parent = code; parent && !language; parent = parent.parentNode) {
      language = /(?:language-|lang-)([\w+-]+)/.exec(parent.getAttribute?.('class') || '')?.[1] || '';
    }
    const text = code.textContent.replace(/\n$/, '');
    const longest = Math.max(2, ...(text.match(/`+/g) || []).map(fence => fence.length));
    const fence = '`'.repeat(longest + 1);
    return `\n\n${fence}${language}\n${text}\n${fence}\n\n`;
  },
});
// Semantic inline elements used as separate lines in the homepage timeline.
turndown.addRule('timelineLines', {
  filter: node => /experience__(?:title|duration|location)/.test(node.getAttribute?.('class') || ''),
  replacement: content => `\n\n${content}\n\n`,
});

export function pageMarkdown(html, canonicalURL, markdownURLs) {
  const { document } = parseHTML(html);
  const content = document.querySelector('main, .site');
  if (!content) throw new Error(`No main content in ${canonicalURL}`);
  const title = (content.querySelector('h1')?.textContent || document.title).trim();
  content.querySelectorAll('script, style, nav, footer, template, #disqus_thread').forEach(node => node.remove());
  // Older blog layouts put the excerpt first. Lead with the title and date,
  // retaining the excerpt exactly once.
  const articleTitle = content.querySelector(':scope > .title');
  if (articleTitle) content.prepend(articleTitle);
  for (const node of content.querySelectorAll('[href], [src]')) {
    for (const attribute of ['href', 'src']) {
      const value = node.getAttribute(attribute);
      if (!value) continue;
      if (value.startsWith('data:')) {
        // Embedded portraits and logos can dwarf the text. Preserve useful alt
        // text, without putting base64 image data in the agent's context.
        if (node.tagName === 'IMG') node.replaceWith(document.createTextNode(node.getAttribute('alt') || ''));
        continue;
      }
      const url = new URL(value, canonicalURL);
      // Fragments target IDs from HTML (including footnotes and custom anchors).
      // Keep those on the canonical page instead of promising Markdown anchors.
      if (attribute === 'href' && !url.hash && markdownURLs.has(url.href)) url.href = markdownURLs.get(url.href);
      node.setAttribute(attribute, url.href);
    }
  }
  for (const node of content.querySelectorAll('iframe, audio, video')) {
    const sources = [node, ...node.querySelectorAll('source')].map(source => source.getAttribute('src')).filter(Boolean);
    const links = document.createElement('p');
    for (const source of sources) {
      const link = document.createElement('a');
      link.href = source;
      link.textContent = node.getAttribute('title') || `${node.tagName.toLowerCase()} recording`;
      links.append(link, document.createElement('br'));
    }
    node.replaceWith(links);
  }
  let markdown = turndown.turndown(content.innerHTML);
  if (!content.querySelector('h1')) markdown = `# ${title}\n\n${markdown}`;
  return `${markdown}\n\n---\n\nCanonical page: ${canonicalURL}\n`;
}

export async function buildMarkdown(site, directory) {
  const config = sites[site];
  if (!config) throw new Error(`Unknown site: ${site}`);
  const pages = [];
  for (const file of (await readdir(directory, { recursive: true })).sort()) {
    if (!file.endsWith('.html')) continue;
    const html = await readFile(`${directory}/${file}`, 'utf8');
    if (!/<html[\s>]/i.test(html)) continue;
    const canonical = new URL(file.replace(/index\.html$/, ''), `${config.origin}/`).href;
    pages.push({ file, html, canonical, markdown: `${config.origin}/${file.replace(/\.html$/, '.md')}` });
  }
  const markdownURLs = new Map();
  for (const page of pages) {
    markdownURLs.set(page.canonical, page.markdown);
    markdownURLs.set(`${config.origin}/${page.file}`, page.markdown);
    if (page.canonical.endsWith('/') && page.file !== 'index.html') markdownURLs.set(page.canonical.slice(0, -1), page.markdown);
  }
  for (const page of pages) {
    await writeFile(`${directory}/${page.file.replace(/\.html$/, '.md')}`, pageMarkdown(page.html, page.canonical, markdownURLs));
    // Insert metadata only; do not reserialize or alter the visible HTML.
    const discovery = `<link rel="alternate" type="text/markdown" href="${page.markdown}">\n<link rel="describedby" type="text/plain" href="${config.origin}/llms.txt">\n`;
    await writeFile(`${directory}/${page.file}`, page.html.replace('</head>', `${discovery}</head>`));
  }
  const links = config.pages.map(([file, title, description]) => {
    if (!pages.some(page => page.markdown === `${config.origin}/${file}`)) throw new Error(`Missing llms.txt target: ${site}/${file}`);
    return `- [${title}](${config.origin}/${file}): ${description}`;
  });
  await writeFile(`${directory}/llms.txt`, `# ${config.title}\n\n> ${config.description}\n\nPages are available as Markdown using the links below, or by requesting their HTML URLs with \`Accept: text/markdown\`. Markdown and HTML are generated from the same published content.\n\n## Content\n\n${links.join('\n')}\n\n## Related sites\n\n${Object.entries(sites).filter(([key]) => key !== site).map(([, other]) => `- [${other.title}](${other.origin}/llms.txt): ${other.description}`).join('\n')}\n`);
  console.log(`${site}: generated ${pages.length} Markdown pages and llms.txt`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [site, directory = `.build/${site}`] = process.argv.slice(2);
  await buildMarkdown(site, directory);
}
